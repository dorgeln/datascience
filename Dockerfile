ARG VERSION_TAG


FROM dorgeln/datascience:arch-${VERSION_TAG} as base
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"
ARG PYTHON_VERSION

LABEL maintainer="Andreas Trawöger <atrawog@dorgeln.org>" org.dorgeln.version=base-${VERSION_TAG} 

USER root
RUN groupadd -g ${NB_GID} users
RUN groupadd -g 998 wheel
RUN useradd -m --uid ${NB_UID} -G wheel ${NB_USER}

RUN sed -i "s/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers
RUN sed -i "s/^#auth		sufficient	pam_wheel.so trust use_uid/auth		sufficient	pam_wheel.so trust use_uid/g" /etc/pam.d/su

# Update Packages, install package dependencies and clean pacman cache
COPY pkglist-core.txt pkglist-core.txt
RUN pacman --noconfirm -Syu && pacman --noconfirm  -S - < pkglist-core.txt && pacman -Scc --noconfirm 
RUN curl -qL https://www.npmjs.com/install.sh | sh

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen &&     locale-gen

ENV ENV_ROOT="/env"

ENV PYENV_ROOT=${ENV_ROOT}/pyenv \
    NPM_DIR=${ENV_ROOT}/npm 

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
    SHELL=/bin/bash

ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin::${NPM_DIR}/bin:$PATH"

RUN mkdir -p ${PYENV_ROOT} ${NPM_DIR}
RUN chown -R ${NB_USER}.${NB_GID} ${ENV_ROOT}

USER ${NB_USER}

RUN npm config --global set update-notifier false
RUN npm config --global set prefix ${NPM_DIR}

ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}
WORKDIR ${NB_USER}

# Build devel image 
FROM dorgeln/datascience:base-${VERSION_TAG} as devel
ARG PYTHON_VERSION


COPY --chown=${NB_USER} pkglist-devel.txt pkglist-devel.txt
RUN sudo pacman --noconfirm  -S - < pkglist-devel.txt && sudo pacman -Scc --noconfirm 

# Install Python via Pyenv
RUN echo ${PYTHON_VERSION} 
WORKDIR ${PYENV_ROOT}
RUN pyenv install -v ${PYTHON_VERSION} && pyenv global ${PYTHON_VERSION}
RUN pip install -U setuptools
RUN pip install -U wheel

FROM dorgeln/datascience:devel-${VERSION_TAG} as npm-devel

WORKDIR ${NPM_DIR}
COPY --chown=${NB_USER} package-core.json  ${NPM_DIR}/package.json
# COPY --chown=${NB_USER} package-lock-core.json  ${NPM_DIR}/package-lock.json

RUN npm install -dd --prefix ${NPM_DIR}
# RUN npm cache clean --force

FROM dorgeln/datascience:npm-devel-${VERSION_TAG} as python-devel

WORKDIR ${PYENV_ROOT}
COPY --chown=${NB_USER} requirements-core.txt requirements-core.txt
RUN pip install -r requirements-core.txt
RUN jupyter serverextension enable nbgitpuller --sys-prefix
RUN jupyter labextension install @jupyterlab/server-proxy && jupyter lab clean -y 

FROM dorgeln/datascience:base-${VERSION_TAG} as deploy

COPY --chown=${NB_USER} --from=python-devel ${ENV_ROOT} ${ENV_ROOT}

ENV XDG_CACHE_HOME="/home/${NB_USER}/.cache/"
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot"

RUN ln -s ${NODE_PATH}  ${HOME}/node_modules

COPY entrypoint /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]
EXPOSE 8888

