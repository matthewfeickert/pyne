ARG ubuntu_version=22.04

FROM ubuntu:${ubuntu_version} AS pyne-deps

# Ubuntu Setup
ENV TZ=America/Chicago
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV HOME=/root
RUN apt-get update \
    && apt-get install -y --fix-missing \
        wget \
        bzip2 \
        ca-certificates \
    && apt-get clean -y

RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" -O ~/miniforge.sh && \
    /bin/bash ~/miniforge.sh -b -p /opt/conda && \
    rm ~/miniforge.sh
    
# put conda on the path
ENV PATH=/opt/conda/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/conda/lib:$LD_LIBRARY_PATH

# install python 3.12 because that's what apt uses
RUN conda install --freeze-installed "python=3.12"
RUN mamba update -n base conda mamba && \
    mamba update -y --all && \
    mamba install -y \
                expat \
                gxx_linux-64 \
                gcc_linux-64 \
                cmake \
                make \
                gfortran \
                libblas \
                liblapack \
                eigen \
                numpy \
                scipy \
                matplotlib \
                git \
                setuptools \
                pytest \
                pytables \
                jinja2 \
                cython \
                future \
                progress \
                meson \
                && \
    mamba clean -y --all

ENV CC=/opt/conda/bin/x86_64-conda-linux-gnu-gcc
ENV CXX=/opt/conda/bin/x86_64-conda-linux-gnu-g++
ENV CPP=/opt/conda/bin/x86_64-conda-linux-gnu-cpp

# install MOAB
RUN conda install "conda-forge::moab=5.5.1"

# install DAGMC
RUN mamba install conda-forge::dagmc

# install OpenMC
RUN mamba install conda-forge::openmc

# Build/Install PyNE from release branch
FROM pyne-deps AS pyne

# make starting directory
RUN mkdir -p $HOME/opt

ENV PYNE_MOAB_ARGS="--moab"
ENV PYNE_DAGMC_ARGS="--dagmc"

COPY . $HOME/opt/pyne
RUN cd $HOME/opt/pyne \
    && python setup.py install --prefix /opt/conda \
                                $PYNE_MOAB_ARGS $PYNE_DAGMC_ARGS \
                                --clean -j 4;

RUN cd $HOME \
    && nuc_data_make \
    && cd $HOME/opt/pyne/tests \
    && pytest -ra
