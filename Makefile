.ONESHELL:
SHELL := /bin/bash
DOCKER_USER := dorgeln
DOCKER_REPO := datascience
ARCH_VERSION := base-devel
PYTHON_VERSION := 3.8.7
POETRY_VERSION := 1.1.5
VERSION_TAG := 0.0.5
ARCH_TAG := arch-${ARCH_VERSION}
PYTHON_TAG := python-${PYTHON_VERSION}
POETRY_TAG := poetry-${POETRY_VERSION}

ARCH_CORE := base-devel git git-lfs pyenv nodejs freetype2 pango cairo giflib libjpeg-turbo openjpeg2 librsvg fontconfig ttf-liberation neofetch 
PYTHON_CORE := numpy matplotlib pandas jupyterlab  altair altair_saver nbgitpuller ipywidgets beautifulsoup4 bokeh bottleneck cloudpickle cython dask dill h5py ipympl numexpr patsy protobuf scikit-image scikit-learn scipy seaborn sqlalchemy statsmodels sympy vincent widgetsnbextension xlrd  invoke jupyter-server-proxy  jupyter-panel-proxy awesome-panel-extensions
PYTHON_FULL := cysgp4 ansible==2.9.18
NPM_CORE := vega-lite vega-cli canvas

deps:
	[ -f  pkglist.txt ] rm pkglist.txt
	for pkg in ${ARCH_CORE}; do \
		echo $$pkg >> pkglist.txt; \
	done
	npm install --package-lock-only ${NPM_CORE}
	[ -f ./package-core.json ] || cp package.json package-core.json;cp package-lock.json package-lock-core.json
	[ -f ./pyproject.toml ] || poetry init -n
	poetry add --lock ${PYTHON_CORE} -v
	[ -f ./pyproject-core.toml ] || cp pyproject.toml pyproject-core.toml;cp poetry.lock poetry-core.lock
	poetry add --lock ${PYTHON_FULL} -v

pull:
	docker pull ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} || true
	docker pull ${DOCKER_USER}/${DOCKER_REPO}:latest || true

build:
	docker image build --cache-from ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG}  --cache-from ${DOCKER_USER}/${DOCKER_REPO}:latest --build-arg ARCH_VERSION=${ARCH_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg POETRY_VERSION=${POETRY_VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${ARCH_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${PYTHON_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${POETRY_TAG} .

build-nocache:
	docker image build --cache-from ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG}  --cache-from ${DOCKER_USER}/${DOCKER_REPO}:latest --build-arg ARCH_VERSION=${ARCH_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg POETRY_VERSION=${POETRY_VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${ARCH_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${PYTHON_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${POETRY_TAG} ..

bash:
	docker run -it ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} bash


run:
	docker run ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG}


push: pull build
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG}
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${ARCH_TAG}
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${PYTHON_TAG}
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${POETRY_TAG}
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:latest

install:
	npm install --unsafe-perm
	poetry install -vvv

clean:
	rm -f pyproject.toml poetry.lock pyproject-core.toml package.json package-lock.json package-core.json poetry-core.lock package-lock-core.json pkglist.txt
