.ONESHELL:
SHELL := /bin/bash
VERSION_TAG := 0.0.9
DOCKER_USER := dorgeln
DOCKER_REPO := datascience
ARCH_VERSION := 20210404.0.18927
PYTHON_VERSION := 3.8.8
PYTHON_REQUIRED := ">=3.8,<3.9"
POETRY_VERSION := 1.1.5
ARCH_TAG := arch-${ARCH_VERSION}
PYTHON_TAG := python-${PYTHON_VERSION}
POETRY_TAG := poetry-${POETRY_VERSION}

ARCH_CORE := sudo git git-lfs pyenv nodejs freetype2 pango cairo giflib libjpeg-turbo openjpeg2 librsvg fontconfig ttf-liberation  
ARCH_DEVEL := base-devel 
ARCH_EXTRA := neofetch
PYTHON_CORE := numpy matplotlib pandas jupyterlab  altair altair_saver nbgitpuller invoke jupyter-server-proxy cysgp4 
PYTHON_FULL := ansible==2.9.19 
NPM_CORE := vega-lite vega-cli canvas configurable-http-proxy 
LOCAL_DIR := $(shell pwd | grep -o "[^/]*\$$" )

export NPM_DIR=${PWD}/.npm
export NODE_PATH=${NPM_DIR}/node_modules
export NPM_CONFIG_GLOBALCONFIG := ${NPM_DIR}/npmrc

env:
	env

arch:
	sudo pacman --noconfirm -S ${ARCH_CORE} ${ARCH_DEVEL} ${ARCH_EXTRA}

pyenv:
	pyenv install -s ${PYTHON_VERSION}
	pyenv local ${PYTHON_VERSION}
	pyenv global ${PYTHON_VERSION}
	python --version
	python -m pip install --upgrade pip
	pip install poetry==${POETRY_VERSION}
	pip install jupyter-repo2docker

deps: 
	[ -f ./package-core.json ] || npm install --package-lock-only ${NPM_CORE};cp package.json package-core.json;cp package-lock.json package-lock-core.json

	poetry config virtualenvs.path .env
	poetry config cache-dir .cache
	poetry config virtualenvs.in-project true

	[ -f ./pyproject.toml ] || poetry init -n --python ${PYTHON_REQUIRED}; sed -i 's/version = "0.1.0"/version = "${VERSION_TAG}"/g' pyproject.toml

	
	[ -f ./pyproject-core.toml ] || poetry add --lock ${PYTHON_CORE} -v;cp pyproject.toml pyproject-core.toml;cp poetry.lock poetry-core.lock
	[ -f ./pyproject-full.toml ] || poetry add --lock ${PYTHON_FULL} -v;cp pyproject.toml pyproject-full.toml;cp poetry.lock poetry-full.lock



	[ -f  pkglist-core.txt ] || 
	for pkg in ${ARCH_CORE}; do \
		echo $$pkg >> pkglist-core.txt; \
	done

	[ -f  pkglist-devel.txt ] || 
	for pkg in ${ARCH_DEVEL}; do \
		echo $$pkg >> pkglist-devel.txt; \
	done	

	[ -f  pkglist-extra.txt ] ||
	for pkg in ${ARCH_EXTRA}; do \
		echo $$pkg >> pkglist-extra.txt; \
	done


pull:
	docker pull ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} || true
	docker pull ${DOCKER_USER}/${DOCKER_REPO}:latest || true

build: 
	docker image build --build-arg ARCH_VERSION=${ARCH_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg POETRY_VERSION=${POETRY_VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${ARCH_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${PYTHON_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${POETRY_TAG} .

build-nocache:
	docker image build --no-cache --build-arg ARCH_VERSION=${ARCH_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg POETRY_VERSION=${POETRY_VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${ARCH_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${PYTHON_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${POETRY_TAG} .

bash:
	docker run -it ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} bash

run:
	docker run ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG}


lab:
	poetry run jupyter-lab

tag:
	-while IFS=$$'=' read -r pkg version; do \
		version=$${version//^}; \
		version=$${version//'"'}; \
		version=$${version//' '}; \
		pkg=$${pkg//' '}; \
		case $$version in \
			'') pkg='';version=''  ;;\
			*[a-zA-Z=]*) pkg='';version='' ;; \
    		*) ;; \
		esac; \
		[ ! $$pkg  = '' ] && docker tag ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} ${DOCKER_USER}/${DOCKER_REPO}:$$pkg-$$version ; \
	done < pyproject.toml

push: build
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG}
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:latest

push-all: clean-tags build tag
	docker image push -a ${DOCKER_USER}/${DOCKER_REPO}


install: 
	npm install --unsafe-perm
	poetry install -vvv

clean:
	-poetry env remove python
	-rm -f pyproject.toml poetry.lock pyproject-core.toml package.json package-lock.json package-core.json poetry-core.lock package-lock-core.json pkglist-core.txt pkglist-devel.txt pkglist-extra.txt pyproject-full.toml


clean-cache:
	poetry cache clear -n --all pypi
	npm cache clean --force

clean-tags:
	docker images | grep dorgeln/datascience | awk '{system("docker rmi " "'"dorgeln/datascience:"'" $2)}'

