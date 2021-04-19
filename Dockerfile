ARG VERSION_TAG
ARG PYTHON_VERSION

FROM dorgeln/datascience:arch-${VERSION_TAG} as base
ARG PYTHON_VERSION

# Glibc fix if you want build images on Docker Hub
# RUN patched_glibc=glibc-linux4-2.33-4-x86_64.pkg.tar.zst && \
#   curl -LO "https://repo.archlinuxcn.org/x86_64/$patched_glibc" && \
#    bsdtar -C / -xvf "$patched_glibc"

# Update Packages, install package dependencies and clean pacman cache
COPY pkglist-core.txt pkglist-core.txt
RUN pacman --noconfirm -Syu && pacman --noconfirm  -S - < pkglist-core.txt && pacman -Scc --noconfirm 

#  Allow sudo and su without password for user in group wheel
RUN sed -i "s/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers
#RUN sed -i "s/^#auth		sufficient	pam_wheel.so trust use_uid/auth		sufficient	pam_wheel.so trust use_uid/g" /etc/pam.d/su

ENV ENV_ROOT="/env"

ENV PYENV_ROOT=${ENV_ROOT}/pyenv \
    NPM_DIR=${ENV_ROOT}/npm 

ENV PYTHONUNBUFFERED=true \
    PYTHONDONTWRITEBYTECODE=true \
    PIP_NO_CACHE_DIR=true \
    PIP_DISABLE_PIP_VERSION_CHECK=true \
    PIP_DEFAULT_TIMEOUT=180 \
    NODE_PATH=${NPM_DIR}/node_modules \
    NPM_CONFIG_GLOBALCONFIG=${NPM_DIR}/npmrc

RUN mkdir -p ${PYENV_ROOT} ${NPM_DIR} ${SRC_DIR}

ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin::${NPM_DIR}/bin:$PATH"

RUN curl -qL https://www.npmjs.com/install.sh | sh

# Build devel image 
FROM dorgeln/datascience:base-${VERSION_TAG} as devel
ARG PYTHON_VERSION

COPY pkglist-devel.txt pkglist-devel.txt
RUN pacman --noconfirm  -S - < pkglist-devel.txt && pacman -Scc --noconfirm 

# Install Python via Pyenv
RUN echo ${PYTHON_VERSION} 
WORKDIR ${PYENV_ROOT}
RUN pyenv install -v ${PYTHON_VERSION} && pyenv global ${PYTHON_VERSION}
RUN pip install -U setuptools
RUN pip install -U wheel

FROM dorgeln/datascience:devel-${VERSION_TAG} as npm-devel

WORKDIR ${NPM_DIR}
COPY package-core.json  ${NPM_DIR}/package.json
COPY package-lock-core.json  ${NPM_DIR}/package-lock.json
RUN npm install -dd --prefix ${NPM_DIR}
RUN npm config --global set update-notifier false
RUN npm config --global set prefix ${NPM_DIR}
RUN npm cache clean --force

FROM dorgeln/datascience:npm-devel-${VERSION_TAG} as python-devel

WORKDIR ${PYENV_ROOT}
COPY requirements-core.txt requirements-core.txt
RUN pip install -r requirements-core.txt
RUN jupyter serverextension enable nbgitpuller --sys-prefix
RUN jupyter labextension install @jupyterlab/server-proxy && jupyter lab clean -y 

FROM dorgeln/datascience:base-${VERSION_TAG} as deploy

COPY --from=python-devel ${ENV_ROOT} ${ENV_ROOT}

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen &&     locale-gen
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV SHELL /bin/bash

ENV NB_USER=jovian 
ENV NB_UID=1000
# ENV NB_GROUPS="adm,kvm,wheel,network,uucp,users"
# RUN useradd -m --uid ${NB_UID} -G ${NB_GROUPS} ${NB_USER}
RUN useradd -m --uid ${NB_UID} ${NB_USER}

ENV USER ${NB_USER}
ENV HOME /home/${USER}

ENV REPO_DIR=${HOME}
WORKDIR ${REPO_DIR}

ENV XDG_CACHE_HOME="/home/${NB_USER}/.cache/"
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot"

RUN ln -s ${NODE_PATH}  ${HOME}/node_modules


COPY entrypoint /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]
EXPOSE 8888


RUN chown -R $USER.$USER ${HOME} ${ENV_ROOT}
USER ${USER}
WORKDIR ${HOME}
