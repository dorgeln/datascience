ARG ARCH_VERSION=base-devel-20210307.0.16708

FROM archlinux:${ARCH_VERSION} as base-devel

# Glibc fix to build image on Docker Hub
RUN patched_glibc=glibc-linux4-2.33-4-x86_64.pkg.tar.zst && \
    curl -LO "https://repo.archlinuxcn.org/x86_64/$patched_glibc" && \
    bsdtar -C / -xvf "$patched_glibc"

# Update Packages, install package dependencies and clean pacman cache
RUN pacman --noconfirm -Syu && pacman --noconfirm  -S --needed base-devel git git-lfs pyenv nodejs freetype2 pango cairo giflib libjpeg-turbo openjpeg2 librsvg fontconfig ttf-liberation neofetch && pacman -Scc --noconfirm 

#  Allow sudo and su without password for user in group wheel
RUN sed -i "s/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers
RUN sed -i "s/^#auth		sufficient	pam_wheel.so trust use_uid/auth		sufficient	pam_wheel.so trust use_uid/g" /etc/pam.d/su

# Install Python via Pyenv
ARG PYTHON_VERSION=3.8.7
ENV PYENV_ROOT="/env/pyenv"
RUN mkdir -p ${PYENV_ROOT}
WORKDIR ${PYENV_ROOT}

RUN pyenv install -v $PYTHON_VERSION && pyenv global $PYTHON_VERSION
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin:$PATH" 

# Install Poetry
ARG POETRY_VERSION=1.1.5
ENV PYTHONUNBUFFERED=true \
    PYTHONDONTWRITEBYTECODE=true \
    PIP_NO_CACHE_DIR=true \
    PIP_DISABLE_PIP_VERSION_CHECK=true \
    PIP_DEFAULT_TIMEOUT=180 \
    POETRY_VIRTUALENVS_CREATE=false \
    POETRY_NO_INTERACTION=true \
    POETRY_HOME="/env/poetry"

RUN curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python
ENV PATH="${POETRY_HOME}/bin:$PATH" 

# Install Python Core dependencies 
RUN mkdir /env/code
WORKDIR /env/code
COPY pyproject-core.toml pyproject.toml 
COPY poetry-core.lock poetry.lock
RUN poetry install -vvv  && jupyter lab clean -y 

# Install npm and nmp core dependencies
RUN curl -qL https://www.npmjs.com/install.sh | sh
ENV NPM_ROOT=/env/npm
ENV NODE_PATH=${NPM_ROOT}/node_modules
RUN mkdir -p ${NPM_ROOT}
WORKDIR ${NPM_ROOT}
COPY package-core.json  ${NPM_ROOT}/package.json
COPY package-lock-core.json  ${NPM_ROOT}/package-lock.json
RUN npm install -dd --prefix ${NPM_ROOT} && npm config set update-notifier false && npm cache clean --force


# Install additional Python and  jupyterlab dependencies 
COPY pyproject.toml pyproject.toml
COPY poetry.lock poetry.lock
RUN poetry install -vvv && jupyter labextension install @jupyterlab/server-proxy && jupyter lab clean -y 


ARG NB_USER=jovian 
ARG NB_UID=1000
ARG NB_GROUPS="adm,kvm,wheel,network,uucp,users"

RUN useradd -m --uid ${NB_UID} -G ${NB_GROUPS} ${NB_USER}

ENV USER ${NB_USER}
ENV HOME /home/${USER}
# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME="/home/${NB_USER}/.cache/"
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot"

RUN ln -s ${NODE_PATH}  ${HOME}/node_modules


