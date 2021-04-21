ARG VERSION
ARG DOCKER_USER
ARG DOCKER_REPO

FROM ${DOCKER_USER}/${DOCKER_REPO}:arch-${VERSION} as base
ARG VERSION
ARG PYTHON_VERSION
ARG DOCKER_USER
ARG DOCKER_REPO
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

LABEL maintainer="Andreas Trawöger <atrawog@dorgeln.org>" org.dorgeln.version=${VERSION} 

RUN groupadd -g ${NB_GID} users && groupadd -g 998 wheel && useradd -m --uid ${NB_UID} -G wheel ${NB_USER}
RUN sed -i "s/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers
RUN sed -i "s/^#auth		sufficient	pam_wheel.so trust use_uid/auth		sufficient	pam_wheel.so trust use_uid/g" /etc/pam.d/su
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen &&     locale-gen

ENV ENV_ROOT="/env" 
ENV PYENV_ROOT=${ENV_ROOT}/pyenv \
    NPM_DIR=${ENV_ROOT}/npm 
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${NPM_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ENV PYTHONUNBUFFERED=true \
    PYTHONDONTWRITEBYTECODE=true \
    PIP_NO_CACHE_DIR=true \
    PIP_DISABLE_PIP_VERSION_CHECK=true \
    PIP_DEFAULT_TIMEOUT=180 \
    NODE_PATH=${NPM_DIR}/node_modules \
    NPM_CONFIG_GLOBALCONFIG=${NPM_DIR}/npmrc\
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    SHELL=/bin/bash \
    NB_USER=${NB_USER} \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    JUPYTER_ENABLE_LAB=yes \
    PYTHON_VERSION=${PYTHON_VERSION} \
    DOCKER_USER=${DOCKER_USER} \
    DOCKER_REPO=${DOCKER_REPO} \
    VERSION=${VERSION} \
    USER=${NB_USER} \
    HOME=/home/${NB_USER} \
    REPO_DIR=/home/${NB_USER} \
    XDG_CACHE_HOME=/home/${NB_USER}/.cache \
    MAKE_OPTS="-j8" \
    CONFIGURE_OPTS="--enable-shared --enable-optimizations --with-computed-gotos" \
    NPY_USE_BLAS_ILP64=1

RUN mkdir -p ${PYENV_ROOT} ${NPM_DIR} && chown -R ${NB_USER}.${NB_GID} ${ENV_ROOT}

RUN curl -qL https://www.npmjs.com/install.sh | sh
USER ${NB_USER}
RUN npm config --global set update-notifier false &&  npm config --global set prefix ${NPM_DIR}

ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}
WORKDIR ${HOME}
RUN ln -s ${NODE_PATH}  ${HOME}/node_modules

COPY entrypoint /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]

CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]
EXPOSE 8888

FROM ${DOCKER_USER}/${DOCKER_REPO}:base-${VERSION} as builder
ARG PYTHON_VERSION

COPY --chown=${NB_USER} pkglist-builder.txt pkglist-builder.txt
RUN sudo pacman --noconfirm  -Sy && sudo pacman --noconfirm  -S - < pkglist-builder.txt && sudo pacman -Scc --noconfirm 

RUN echo ${PYTHON_VERSION} 
WORKDIR ${PYENV_ROOT}
RUN pyenv install -v ${PYTHON_VERSION} && pyenv global ${PYTHON_VERSION}
RUN pip install -U setuptools -U wheel

WORKDIR ${NPM_DIR}
COPY --chown=${NB_USER} package-base.json  ${NPM_DIR}/package.json
RUN npm install --verbose -dd --prefix ${NPM_DIR} && npm cache clean --force

WORKDIR ${PYENV_ROOT}
COPY --chown=${NB_USER} requirements-base.txt requirements-base.txt
RUN pip install -vv -r requirements-base.txt
RUN jupyter serverextension enable nbgitpuller --sys-prefix && jupyter serverextension enable --sys-prefix jupyter_server_proxy && jupyter labextension install @jupyterlab/server-proxy && jupyter lab clean -y && npm cache clean --force

FROM ${DOCKER_USER}/${DOCKER_REPO}:base-${VERSION}  as deploy

COPY --chown=${NB_USER} --from=builder ${ENV_ROOT} ${ENV_ROOT}


