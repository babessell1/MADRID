# TODO: Use multistage builds to reduce image size
# From: https://medium.com/nexton/how-to-optimize-docker-images-using-dive-dc590f45dbf5
# https://stackoverflow.com/questions/58597728


FROM rocker/r-ubuntu:20.04 as stage1

#### Set Container Args ####
ARG APT_INSTALLATION_FILE=apt_installation_requirements.txt
ARG GRB_SHORT_VERSION=9.5
ARG GRB_VERSION=9.5.0
ARG TINI_VERSION=v0.19.0
ARG TINI_LOCATION=/usr/local/bin/tini

# Set static environment variables
ENV CRAN_MIRROR=https://cloud.r-project.org
ENV GUROBI_HOME /opt/gurobi/linux64
ENV JUPYTER_ENABLE_LAB=1
ENV NB_UID=1001
ENV NB_GID=1001
ENV NB_USER=jupyteruser
ENV SHELL=/bin/bash

# Set potentially dynamic environment variables
ENV LD_LIBRARY_PATH $GUROBI_HOME/lib
ENV PATH $PATH:$GUROBI_HOME/bin
ENV HOME /home/${NB_USER}

LABEL vendor="Gurobi"
LABEL version=${GRB_VERSION}
WORKDIR /opt

USER root

#### Copy Install Scripts ####
COPY build_scripts/jupyter_python_setup.sh /opt/
COPY build_scripts/apt_installation_requirements.txt /opt/

# Download TINI
# From: https://github.com/krallin/tini#using-tini
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini ${TINI_LOCATION}
RUN chmod +x ${TINI_LOCATION}

#### Install Juypter and Python Libraries ####
# Add user & system related items
# i.e., creating new user
RUN groupadd --gid "${NB_GID}" "${NB_USER}" \
    # && useradd --create-home --shell "${SHELL}" --no-user-group --uid "${NB_UID}" --gid "${NB_UID}" "${NB_USER}" \
    && useradd --create-home --shell "${SHELL}" --uid "${NB_UID}" --gid "${NB_GID}" "${NB_USER}" \
    # Add user to sudoers
    && echo "${NB_USER}" 'ALL=(ALL) NOPASSWD: /usr/bin/apt-get' >> /etc/sudoers

# Install R packages from source (not available on r-cran)
# Install in background; From: # From: https://www.balena.io/docs/learn/deploy/build-optimization/#starting-long-running-tasks-together
# Must group '&' commands with (); From: https://stackoverflow.com/a/52323968
# Start by installing package managers
RUN ( R -e "install.packages('devtools', dependencies=TRUE, repo='${CRAN_MIRROR}')" & ) \
    && ( R -e "if (!requireNamespace('BiocManager', quietly = TRUE)) install.packages('BiocManager')" & ) \
    && wait

# Install BiocManager & GitHub packages
RUN ( R -e "devtools::install_github('babessell1/zFPKM', dependencies=TRUE)" & ) \
    && ( R -e "devtools::install_github('husson/FactoMineR', dependencies=TRUE)" & ) \
    && ( R -e "BiocManager::install('DESeq2', dep=TRUE, ask=FALSE)" & ) \
    && ( R -e "BiocManager::install('agilp', dep=TRUE, ask=FALSE)" & ) \
    && ( R -e "BiocManager::install('hgu133acdf', dep=TRUE, ask=FALSE)" & ) \
    && ( R -e "BiocManager::install('uwot', dep=TRUE, ask=FALSE)" & ) \
    && ( R -e "BiocManager::install('IRkernel', dep=TRUE, ask=FALSE)" & ) \
    && ( R -e "BiocManager::install('IRdisplay', dep=TRUE, ask=FALSE)" & ) \
    && wait

# Install required packages
# First insall wget & curl
RUN apt update -qq \
    && apt install -y wget curl gpg-agent software-properties-common libssl-dev libxml2-dev\
    #Add yarn repository
    && wget -O - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    # Add node apt repository
    && curl -sL https://deb.nodesource.com/setup_14.x | bash - \
    # Add R APT repo, python repo, and apt-fast repo
    && add-apt-repository ppa:c2d4u.team/c2d4u4.0+ \
    && add-apt-repository ppa:deadsnakes/ppa \
    && add-apt-repository ppa:apt-fast/stable  \
    # Update to install required packages
    && apt update -qq \
    # We need non-interactive installation
    && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-fast \
    # Install APT items from file (to reduce visual clutter), https://askubuntu.com/a/1368083/1175774
    && apt-fast install -y $(grep -o '^[^#]*' /opt/${APT_INSTALLATION_FILE}) \
    && update-ca-certificates \
    # Install node/npm packages
    && npm install -g configurable-http-proxy \
    # Install python3 pip \
    && curl --silent --show-error https://bootstrap.pypa.io/get-pip.py | python3.10 \
    # Remove cahce items
    && apt purge -y python3.8 apt-fast \
    && apt autoremove -y \
    && apt clean \
    && npm cache clean --force \
    && rm -rf /tmp/npm* \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /var/cache/apt/apt-fast/*.deb \
    && rm -f /opt/apt_install.txt

# Install additional github-related packages & install them
# First download gurbori and jupyter at the same time
RUN wget --quiet https://packages.gurobi.com/${GRB_SHORT_VERSION}/gurobi${GRB_VERSION}_linux64.tar.gz \
    # Add jupyter scripts emerging as ad hoc interface
    && git clone --depth=1 https://github.com/jupyter/docker-stacks.git /tmp/docker-stacks \
    # Untar gurbori, cleanup extra files
    && tar -xf gurobi${GRB_VERSION}_linux64.tar.gz \
    && rm -f gurobi${GRB_VERSION}_linux64.tar.gz \
    && mv -f gurobi* gurobi \
    # Change 'jovyan' user to ${NB_USER}, and write the resulting file to /usr/local/bin/
    && sed -e 's/jovyan/'"${NB_USER}"'/g' /tmp/docker-stacks/base-notebook/start.sh > /usr/local/bin/start.sh \
    # Copy jupyter installation scripts
    && cp /tmp/docker-stacks/base-notebook/start-notebook.sh /usr/local/bin \
    && cp /tmp/docker-stacks/base-notebook/start-singleuser.sh /usr/local/bin \
    && mkdir -p /etc/jupyter \
    && cp /tmp/docker-stacks/base-notebook/jupyter_server_config.py /etc/jupyter \
    # Remove extra files
    && rm -rf /tmp/docker-stacks \
    && rm -rf gurobi/linux64/docs

# Make installation scripts executable, then execute
RUN chmod +x /usr/local/bin/tini \
    && chmod +x /usr/local/bin/start-notebook.sh \
    && chmod +x /usr/local/bin/start.sh \
    # Link python3.10
    && unlink `which python3` \
    && ln -s `which python3.10` /usr/local/bin/python3 \
    && ln -s `which python3.10` /usr/local/bin/python

# Set up virtual environment & install required libraries
RUN sh /opt/virtual_env_setup.sh \
    && rm -f /opt/virtual_env_setup.sh \
    && rm -f /opt/${APT_INSTALLATION_FILE}

# Used to allow access to the gurobi installer inside MADRID
WORKDIR /opt/gurobi

#### Ownership ####
COPY pipelines/ ${HOME}/work/
RUN chown -R "${NB_USER}" ${HOME} && \
    chown -R "${NB_USER}" /usr/local/lib/R/site-library

#### Set workspace and run Juypterlab ####
USER $NB_USER
WORKDIR ${HOME}
EXPOSE 8888
ENTRYPOINT ["/usr/local/bin/tini", "--"]
CMD ["start-notebook.sh"]


# FROM rocker/r-ubuntu:20.04 as stage2
