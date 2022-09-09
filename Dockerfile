FROM jupyter/r-notebook:latest

ARG GRB_SHORT_VERSION=9.5
ARG GRB_VERSION=9.5.0
ARG PYTHON_VERSION=3.10.4

ENV HOME /home/jovyan

COPY build_scripts/mamba_install.txt "${HOME}"/mamba_install.txt
COPY build_scripts/pip_install.txt "${HOME}"/pip_install.txt

# Give ownership to jovyan user
COPY --chown=1000:100 main "${HOME}"/main

# Install python-related items
RUN conda config --add channels conda-forge \
    && conda config --add channels bioconda \
    && conda config --add channels r \
    && conda config --add channels bioconda  \
    # Remove python from pinned versions; this allows us to update python. From: https://stackoverflow.com/a/11245372/13885200 \
    && sed -i "s/^python 3.*//" /opt/conda/conda-meta/pinned \
    && pip install --no-cache-dir --requirement "${HOME}/pip_install.txt" \
    && mamba install --yes python=${PYTHON_VERSION} --file "${HOME}/mamba_install.txt"\
    && mamba clean --all --force-pkgs-dirs --yes \
    && R -e 'devtools::install_github("babessell1/zFPKM")' \
    # Install jupyter extensions
    && jupyter labextension install @jupyter-widgets/jupyterlab-manager \
    && jupyter labextension install escher \
    && jupyter trust "${HOME}/work/py/pipeline.ipynb" \
    && rm -f "${HOME}/pip_install.txt" \
    && rm -f "${HOME}/mamba_install.txt"

# Install gurbori
RUN wget --quiet https://packages.gurobi.com/${GRB_SHORT_VERSION}/gurobi${GRB_VERSION}_linux64.tar.gz \
    && tar -xf gurobi${GRB_VERSION}_linux64.tar.gz \
    && rm -f gurobi${GRB_VERSION}_linux64.tar.gz \
    && mv -f gurobi* gurobi \
    && rm -rf gurobi/linux64/docs

# Update jupyter notebook configuration \
RUN echo "c.ServerApp.ip = '0.0.0.0'" >> "${HOME}/.jupyter/jupyter_notebook_config.py" \
    && echo "c.ServerApp.root_dir = '${HOME}/work'" >> "${HOME}/.jupyter/jupyter_notebook_config.py" \
    && echo "c.ServerApp.token = ''" >> "${HOME}/.jupyter/jupyter_notebook_config.py" \
    && echo "c.ServerApp.password = ''" >> ${HOME}/.jupyter/jupyter_notebook_config.py

VOLUME /home/joyvan/work
