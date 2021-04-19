.ONESHELL:
SHELL := /bin/bash
VERSION := 0.0.14
DOCKER_USER := dorgeln
DOCKER_REPO := datascience
PYTHON_VERSION := 3.8.8
PYTHON_REQUIRED := ">=3.8,<3.9"
PYTHON_TAG := python-${PYTHON_VERSION}

BUILDDIR=$(shell pwd)/rootfs

ARCH_BASE := filesystem util-linux procps-ng  findutils	 glibc bash pacman sed grep tar gzip xz which sudo git git-lfs pyenv neofetch nodejs-lts-fermium  fontconfig ttf-liberation
ARCH_BUILDER := base base-devel freetype2 pango cairo giflib libjpeg-turbo openjpeg2 librsvg 
PYTHON_BASE := numpy matplotlib pandas jupyterlab altair altair_saver nbgitpuller jupyter-server-proxy cysgp4 bokeh scipy jupyter_bokeh
NPM_BASE := vega-lite vega-cli canvas configurable-http-proxy 
LOCAL_DIR := $(shell pwd | grep -o "[^/]*\$$" )

export NPM_DIR=${PWD}/.npm
export NODE_PATH=${NPM_DIR}/node_modules
export NPM_CONFIG_GLOBALCONFIG := ${NPM_DIR}/npmrc

env:
	env

arch:
	sudo pacman --noconfirm -S ${ARCH_CORE} ${ARCH_BUILDER} ${ARCH_EXTRA}

pyenv:
	pyenv install -s ${PYTHON_VERSION}
	pyenv local ${PYTHON_VERSION}
	pyenv global ${PYTHON_VERSION}
	python --version
	python -m pip install --upgrade pip
	pip install poetry==${POETRY_VERSION}
	pip install jupyter-repo2docker

deps: 
	[ -f ./package-base.json ] || npm install --package-lock-only ${NPM_BASE};cp package.json package-base.json
	[ -f ./pyproject.toml ] || poetry init -n --python ${PYTHON_REQUIRED}; sed -i 's/version = "0.1.0"/version = "${VERSION}"/g' pyproject.toml; poetry config virtualenvs.path .env;poetry config cache-dir .cache;poetry config virtualenvs.in-project true 

	[ -f ./requirements-base.txt || poetry add --lock ${PYTHON_BASE} -v;poetry export --without-hashes -f requirements.txt -o requirements-base.txt

	[ -f  pkglist-base.txt ] || 
	for pkg in ${ARCH_CORE}; do \
		echo $$pkg >> pkglist-base.txt; \
	done

	[ -f  pkglist-builder.txt ] || 
	for pkg in ${ARCH_BUILDER}; do \
		echo $$pkg >> pkglist-builder.txt; \
	done	


build-arch: clean-rootfs
	mkdir -vp $(BUILDDIR)/var/lib/pacman/ $(OUTPUTDIR)
	install -Dm644 /usr/share/devtools/pacman-extra.conf $(BUILDDIR)/etc/pacman.conf
	cat pacman-conf.d-noextract.conf >> $(BUILDDIR)/etc/pacman.conf


	fakechroot -- fakeroot -- pacman -Sy -r $(BUILDDIR) \
		--noconfirm --dbpath $(BUILDDIR)/var/lib/pacman \
		--config $(BUILDDIR)/etc/pacman.conf \
		--noscriptlet \
		${ARCH_BASE}

	fakechroot -- fakeroot -- chroot $(BUILDDIR) update-ca-trust
	fakechroot -- fakeroot -- chroot $(BUILDDIR) locale-gen
	fakechroot -- fakeroot -- chroot $(BUILDDIR) sh -c 'pacman-key --init && pacman-key --populate archlinux && bash -c "rm -rf etc/pacman.d/gnupg/{openpgp-revocs.d/,private-keys-v1.d/,pubring.gpg~,gnupg.S.}*"'
	cp /etc/pacman.d/mirrorlist $(BUILDDIR)/etc/pacman.d/mirrorlist 
	ln -fs /usr/lib/os-release $(BUILDDIR)/etc/os-release

	sed -i -e 's/^root::/root:!:/' "$(BUILDDIR)/etc/shadow"
	sed -i "s/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g" "$(BUILDDIR)/etc/sudoers"

	fakeroot -- tar --numeric-owner --xattrs --acls --exclude-from=exclude -C $(BUILDDIR) -c . | docker import - ${DOCKER_USER}/${DOCKER_REPO}:arch-${VERSION}

bash-arch:
	docker run -it  ${DOCKER_USER}/${DOCKER_REPO}:arch-${VERSION} bash

pull:
	docker pull ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} || true
	docker pull ${DOCKER_USER}/${DOCKER_REPO}:arch-${VERSION} || true

build:
	docker image build --target base --build-arg VERSION=${VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg DOCKER_USER=${DOCKER_USER} --build-arg DOCKER_REPO=${DOCKER_REPO}  -t ${DOCKER_USER}/${DOCKER_REPO}:base-${VERSION} .
	docker image build --target builder --build-arg VERSION=${VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg DOCKER_USER=${DOCKER_USER} --build-arg DOCKER_REPO=${DOCKER_REPO} -t ${DOCKER_USER}/${DOCKER_REPO}:builder-${VERSION} .
	docker image build --target deploy --build-arg VERSION=${VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg DOCKER_USER=${DOCKER_USER} --build-arg DOCKER_REPO=${DOCKER_REPO} -t ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:${PYTHON_TAG} .

bash:
	docker run -it ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} bash

bash-base:
	docker run -it ${DOCKER_USER}/${DOCKER_REPO}:base-${VERSION} bash

bash-builder:
	docker run -it ${DOCKER_USER}/${DOCKER_REPO}:devel-${VERSION} bash

run:
	docker run ${DOCKER_USER}/${DOCKER_REPO}:${VERSION}


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
		[ ! $$pkg  = '' ] && docker tag ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} ${DOCKER_USER}/${DOCKER_REPO}:$$pkg-$$version ; \
	done < pyproject.toml
	docker tag ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} ${DOCKER_USER}/${DOCKER_REPO}:latest

push: build
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${VERSION}


push-all: clean-tags build tag
	docker image push -a ${DOCKER_USER}/${DOCKER_REPO}


install: 
	npm install --verbose --unsafe-perm
	poetry install -vvv

clean-rootfs:
	-rm -rf $(BUILDDIR)

clean: clean-rootfs
	-rm -f package.json package-base.json package-lock.json poetry.lock pyproject.toml requirements-base.txt
	

clean-all: clean
	-rm -rf node_modules .venv .cache

clean-tags:
	docker images | grep dorgeln/datascience | awk '{system("docker rmi " "'"dorgeln/datascience:"'" $2)}'