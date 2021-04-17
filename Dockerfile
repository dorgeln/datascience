<<<<<<< HEAD
ARG ARCH_VERSION
FROM archlinux:base-${ARCH_VERSION} as core
=======
ARG PYTHON_VERSION

FROM dorgeln/archlinux:latest as base
ARG PYTHON_VERSION
>>>>>>> 0.0.11

# Glibc fix if you want build images on Docker Hub
# RUN patched_glibc=glibc-linux4-2.33-4-x86_64.pkg.tar.zst && \
#   curl -LO "https://repo.archlinuxcn.org/x86_64/$patched_glibc" && \
#    bsdtar -C / -xvf "$patched_glibc"

# Update Packages, install package dependencies and clean pacman cache
COPY pkglist-core.txt pkglist-core.txt
<<<<<<< HEAD

RUN pacman --noconfirm -Syu && pacman --noconfirm  -S - < pkglist-core.txt && pacman -Scc --noconfirm 
RUN sed -i "s/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers
RUN sed -i "s/^#auth		sufficient	pam_wheel.so trust use_uid/auth		sufficient	pam_wheel.so trust use_uid/g" /etc/pam.d/su

FROM core as devel

COPY pkglist-devel.txt pkglist-devel.txt
RUN pacman --noconfirm  -S - < pkglist-devel.txt && pacman -Scc --noconfirm 
=======
RUN pacman --noconfirm -Syu && pacman --noconfirm  -S - < pkglist-core.txt && pacman -Scc --noconfirm 
>>>>>>> 0.0.11

#  Allow sudo and su without password for user in group wheel
RUN sed -i "s/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers
RUN sed -i "s/^#auth		sufficient	pam_wheel.so trust use_uid/auth		sufficient	pam_wheel.so trust use_uid/g" /etc/pam.d/su

ENV ENV_ROOT="/env"

ENV PYENV_ROOT=${ENV_ROOT}/pyenv \
    POETRY_HOME=${ENV_ROOT}/poetry \
    NPM_DIR=${ENV_ROOT}/npm 

ENV PYTHONUNBUFFERED=true \
    PYTHONDONTWRITEBYTECODE=true \
    PIP_NO_CACHE_DIR=true \
    PIP_DISABLE_PIP_VERSION_CHECK=true \
    PIP_DEFAULT_TIMEOUT=180 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_NO_INTERACTION=true  \
    NODE_PATH=${NPM_DIR}/node_modules \
    NPM_CONFIG_GLOBALCONFIG=${NPM_DIR}/npmrc

RUN mkdir -p ${PYENV_ROOT} ${POETRY_HOME} ${NPM_DIR} ${SRC_DIR}

ENV PATH="${POETRY_HOME}/bin:${PYENV_ROOT}/shims:${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin::${NPM_DIR}/bin:$PATH"

RUN curl -qL https://www.npmjs.com/install.sh | sh

# Build devel image 
FROM base as python-devel
ARG PYTHON_VERSION

COPY pkglist-devel.txt pkglist-devel.txt
RUN pacman --noconfirm  -S - < pkglist-devel.txt && pacman -Scc --noconfirm 

# Install Python via Pyenv
RUN echo ${PYTHON_VERSION} 
WORKDIR ${PYENV_ROOT}
RUN pyenv install -v ${PYTHON_VERSION} && pyenv global ${PYTHON_VERSION}
RUN pip install -U setuptools
RUN pip install -U wheel

# Install Poetry and Python Core dependencies 
WORKDIR ${POETRY_HOME}
RUN curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python
RUN chmod 755 /env/poetry/bin/poetry
COPY pyproject-core.toml pyproject.toml 
COPY poetry-core.lock poetry.lock
RUN poetry install -vvv
RUN poetry cache clear python --all
RUN rm -rf /env/poetry/lib/poetry/_vendor/py2.7 /env/poetry/lib/poetry/_vendor/py3.5  /env/poetry/lib/poetry/_vendor/py3.6  /env/poetry/lib/poetry/_vendor/py3.7  /env/poetry/lib/poetry/_vendor/py3.9

<<<<<<< HEAD
# Install npm and nmp core dependencies
ENV NPM_DIR=${APP_BASE}/npm
ENV NODE_PATH=${NPM_DIR}/node_modules
ENV NPM_CONFIG_GLOBALCONFIG ${NPM_DIR}/npmrc
RUN mkdir -p ${NPM_DIR}/bin
ENV PATH="$PATH:${NPM_DIR}/bin" 
=======
FROM python-devel as npm-devel

>>>>>>> 0.0.11
WORKDIR ${NPM_DIR}
COPY package-core.json  ${NPM_DIR}/package.json
COPY package-lock-core.json  ${NPM_DIR}/package-lock.json
RUN npm install -dd --prefix ${NPM_DIR}
RUN npm config --global set update-notifier false
RUN npm config --global set prefix ${NPM_DIR}
RUN npm cache clean --force
<<<<<<< HEAD

# Install additional Python and  jupyterlab dependencies
WORKDIR /${APP_BASE}/code
COPY pyproject-full.toml pyproject.toml
COPY poetry-full.lock poetry.lock
RUN poetry install -vvv && jupyter labextension install @jupyterlab/server-proxy && jupyter lab clean -y 
=======

FROM npm-devel as  python-core
WORKDIR ${POETRY_HOME}
RUN curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python
RUN chmod 755 /env/poetry/bin/poetry
COPY pyproject-core.toml pyproject.toml 
COPY poetry-core.lock poetry.lock
RUN poetry install -vvv
RUN jupyter serverextension enable nbgitpuller --sys-prefix
RUN jupyter labextension install @jupyterlab/server-proxy && jupyter lab clean -y 

FROM base as deploy

COPY --from=python-core ${ENV_ROOT} ${ENV_ROOT}

COPY pkglist-extra.txt pkglist-extra.txt
RUN pacman --noconfirm -Syu && pacman --noconfirm  -S - < pkglist-extra.txt && pacman -Scc --noconfirm 
>>>>>>> 0.0.11

FROM core as deploy

COPY pkglist-extra.txt pkglist-extra.txt
RUN pacman --noconfirm -Syu && pacman --noconfirm  -S - < pkglist-extra.txt && pacman -Scc --noconfirm 

ENV APP_BASE /env
ENV PYENV_ROOT=${APP_BASE}/pyenv
COPY --from=devel /env /env

ARG PYTHON_VERSION
ENV PATH=${PYENV_ROOT}/shims:${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin:$PATH

ENV PYTHONUNBUFFERED=true \
    PYTHONDONTWRITEBYTECODE=true \
    PIP_NO_CACHE_DIR=true \
    PIP_DISABLE_PIP_VERSION_CHECK=true \
    PIP_DEFAULT_TIMEOUT=180 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_NO_INTERACTION=true \
    POETRY_HOME=${APP_BASE}/poetry
ENV PATH="${POETRY_HOME}/bin:$PATH" 


ENV NPM_DIR=${APP_BASE}/npm
ENV NODE_PATH=${NPM_DIR}/node_modules
ENV NPM_CONFIG_GLOBALCONFIG ${NPM_DIR}/npmrc

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen &&     locale-gen
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV SHELL /bin/bash

ENV NB_USER=jovian 
ENV NB_UID=1000
ENV NB_GROUPS="adm,kvm,wheel,network,uucp,users"
RUN useradd -m --uid ${NB_UID} -G ${NB_GROUPS} ${NB_USER}
RUN jupyter serverextension enable nbgitpuller --sys-prefix


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