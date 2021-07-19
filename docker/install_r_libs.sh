mkdir /home/"${NB_USER}"/rlibs
chown -R "${NB_USER}" /home/"${NB_USER}"/rlibs
R -e 'if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")'
R -e 'BiocManager::install("affy", dep=TRUE, ask=FALSE, lib="/home/jupyteruser/rlibs")'
R -e 'BiocManager::install("agilp", dep=TRUE, ask=FALSE, lib="/home/jupyteruser/rlibs")'
R -e 'BiocManager::install("limma", dep=TRUE, ask=FALSE, lib="/home/jupyteruser/rlibs")'
R -e 'BiocManager::install("hgu133acdf", dep=TRUE, ask=FALSE, lib="/home/jupyteruser/rlibs")'
R -e 'install.packages(c("rzmq","repr","IRkernel","IRdisplay"), repos = c("http://irkernel.github.io/", getOption("repos")), type = "source", lib="/home/jupyteruser/rlibs")'
R -e 'install.packages(c("tidyverse", "sjmisc"), dependencies=TRUE, repos="'"${CRAN_MIRROR}"'", lib="/home/jupyteruser/rlibs")'
R -e 'BiocManager::install("genefilter", dep=TRUE, ask=FALSE, lib="/home/jupyteruser/rlibs")'
R -e 'BiocManager::install("biomaRt", dep=TRUE, ask=FALSE, lib="/home/jupyteruser/rlibs")'