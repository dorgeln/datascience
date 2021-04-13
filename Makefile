.ONESHELL:
SHELL := /bin/bash
VERSION_TAG := 0.0.7
DOCKER_USER := dorgeln
DOCKER_REPO := datascience
ARCH_VERSION := base-devel-20210404.0.18927
PYTHON_VERSION := 3.8.8
PYTHON_REQUIRED := ">=3.8,<3.9"
POETRY_VERSION := 1.1.5
ARCH_TAG := arch-${ARCH_VERSION}
PYTHON_TAG := python-${PYTHON_VERSION}
POETRY_TAG := poetry-${POETRY_VERSION}

ARCH_CORE := base-devel git git-lfs pyenv nodejs freetype2 pango cairo giflib libjpeg-turbo openjpeg2 librsvg fontconfig ttf-liberation neofetch 
ARCH_EXTRA := 
PYTHON_CORE := numpy matplotlib pandas jupyterlab  altair altair_saver nbgitpuller invoke jupyter-server-proxy cysgp4 
PYTHON_FULL := ansible==2.9.19 
NPM_CORE := vega-lite vega-cli canvas configurable-http-proxy 


pyenv:
	pyenv install -s ${PYTHON_VERSION}
	pyenv local ${PYTHON_VERSION}
	pyenv global ${PYTHON_VERSION}
	python --version
	python -m pip install --upgrade pip
	pip install poetry==${POETRY_VERSION}
	pip install jupyter-repo2docker
	poetry run python -m pip install --upgrade pip

npm:
	curl -qL https://www.npmjs.com/install.sh | sudo sh

deps: 
	[ -f ./pyproject.toml ] || poetry init -n --python ${PYTHON_REQUIRED}; sed -i 's/version = "0.1.0"/version = "${VERSION_TAG}"/g' pyproject.toml

	poetry add --lock ${PYTHON_CORE} -v
	[ -f ./pyproject-core.toml ] || cp pyproject.toml pyproject-core.toml;cp poetry.lock poetry-core.lock
	poetry add --lock ${PYTHON_FULL} -v

	[ -f  pkglist-core.txt ] || 
	for pkg in ${ARCH_CORE}; do \
		echo $$pkg >> pkglist-core.txt; \
	done
	[ -f ./package-core.json ] || npm install --package-lock-only ${NPM_CORE};cp package.json package-core.json;cp package-lock.json package-lock-core.json

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
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${ARCH_TAG}
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${PYTHON_TAG}
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${POETRY_TAG}
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:latest

push-all: build tag
	docker image push -a ${DOCKER_USER}/${DOCKER_REPO}


devel: 
	npm install --unsafe-perm
	poetry install -vvv

clean:
	-poetry env remove python
	-rm -f pyproject.toml poetry.lock pyproject-core.toml package.json package-lock.json package-core.json poetry-core.lock package-lock-core.json pkglist-core.txt pkglist-full.txt


