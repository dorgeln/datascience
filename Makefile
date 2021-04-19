.ONESHELL:
SHELL := /bin/bash
<<<<<<< HEAD
VERSION_TAG := 0.0.11
DOCKER_USER := dorgeln
DOCKER_REPO := datascience
=======
VERSION_TAG := 0.0.9
DOCKER_USER := dorgeln
DOCKER_REPO := datascience
ARCH_VERSION := 20210404.0.18927
>>>>>>> a691de5 (version-0.0.9)
PYTHON_VERSION := 3.8.8
PYTHON_REQUIRED := ">=3.8,<3.9"
PYTHON_TAG := python-${PYTHON_VERSION}

<<<<<<< HEAD
BUILDDIR=$(shell pwd)/rootfs

ARCH_BASE := filesystem glibc bash pacman sed grep tar gzip xz which sudo git git-lfs pyenv neofetch
ARCH_CORE := nodejs-lts-fermium  fontconfig ttf-liberation
ARCH_DEVEL := base-devel freetype2 pango cairo giflib libjpeg-turbo openjpeg2 librsvg
ARCH_EXTRA := neofetch
PYTHON_CORE := numpy matplotlib pandas jupyterlab altair altair_saver nbgitpuller jupyter-server-proxy cysgp4
=======
ARCH_CORE := sudo git git-lfs pyenv nodejs freetype2 pango cairo giflib libjpeg-turbo openjpeg2 librsvg fontconfig ttf-liberation  
ARCH_DEVEL := base-devel 
ARCH_EXTRA := neofetch
PYTHON_CORE := numpy matplotlib pandas jupyterlab  altair altair_saver nbgitpuller invoke jupyter-server-proxy cysgp4 
PYTHON_FULL := ansible==2.9.19 
>>>>>>> a691de5 (version-0.0.9)
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
<<<<<<< HEAD
	[ -f ./pyproject.toml ] || poetry init -n --python ${PYTHON_REQUIRED}; sed -i 's/version = "0.1.0"/version = "${VERSION_TAG}"/g' pyproject.toml; poetry config virtualenvs.path .env;poetry config cache-dir .cache;poetry config virtualenvs.in-project true 

	[ -f ./requirements-core.txt || poetry add --lock ${PYTHON_CORE} -v;poetry export --without-hashes -f requirements.txt -o requirements-core.txt
=======

	poetry config virtualenvs.path .env
	poetry config cache-dir .cache
	poetry config virtualenvs.in-project true

	[ -f ./pyproject.toml ] || poetry init -n --python ${PYTHON_REQUIRED}; sed -i 's/version = "0.1.0"/version = "${VERSION_TAG}"/g' pyproject.toml

	
	[ -f ./pyproject-core.toml ] || poetry add --lock ${PYTHON_CORE} -v;cp pyproject.toml pyproject-core.toml;cp poetry.lock poetry-core.lock
	[ -f ./pyproject-full.toml ] || poetry add --lock ${PYTHON_FULL} -v;cp pyproject.toml pyproject-full.toml;cp poetry.lock poetry-full.lock


>>>>>>> a691de5 (version-0.0.9)

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

	[ -f  pkglist-extra.txt ] ||
	for pkg in ${ARCH_EXTRA}; do \
		echo $$pkg >> pkglist-extra.txt; \
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

#	fakechroot -- fakeroot -- pacman -Rdd -r $(BUILDDIR) \
#		--noconfirm --dbpath $(BUILDDIR)/var/lib/pacman \
#		--config $(BUILDDIR)/etc/pacman.conf \
#		--noscriptlet \
#		linux-api-headers iana-etc systemd-libs libcap libcap-ng libldap pcre


	# remove passwordless login for root (see CVE-2019-5021 for reference)
	sed -i -e 's/^root::/root:!:/' "$(BUILDDIR)/etc/shadow"

	# fakeroot to map the gid/uid of the builder process to root
	# fixes #22
	fakeroot -- tar --numeric-owner --xattrs --acls --exclude-from=exclude -C $(BUILDDIR) -c . | docker import - ${DOCKER_USER}/${DOCKER_REPO}:arch-${VERSION_TAG}



pull:
	docker pull ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} || true
	docker pull ${DOCKER_USER}/${DOCKER_REPO}:latest || true

build:
	docker image build --target base --build-arg VERSION_TAG=${VERSION_TAG} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:base-${VERSION_TAG} .
	docker image build --target devel --build-arg VERSION_TAG=${VERSION_TAG} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:devel-${VERSION_TAG} .
	docker image build --target npm-devel  --build-arg VERSION_TAG=${VERSION_TAG} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:npm-devel-${VERSION_TAG} .
	docker image build --target python-devel --build-arg VERSION_TAG=${VERSION_TAG} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:python-devel-${VERSION_TAG} .
	docker image build --target deploy --build-arg VERSION_TAG=${VERSION_TAG} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} -t ${DOCKER_USER}/${DOCKER_REPO}:${PYTHON_TAG} .

bash:
	docker run -it ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} bash

bash-base:
	docker run -it ${DOCKER_USER}/${DOCKER_REPO}:base bash

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
	docker tag ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG} ${DOCKER_USER}/${DOCKER_REPO}:latest

push: build
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${VERSION_TAG}

<<<<<<< HEAD

=======
>>>>>>> a691de5 (version-0.0.9)
push-all: clean-tags build tag
	docker image push -a ${DOCKER_USER}/${DOCKER_REPO}


install: 
	npm install --unsafe-perm
	poetry install -vvv

<<<<<<< HEAD
clean-rootfs:
	-rm -rf $(BUILDDIR)
=======
clean:
	-poetry env remove python
	-rm -f pyproject.toml poetry.lock pyproject-core.toml package.json package-lock.json package-core.json poetry-core.lock package-lock-core.json pkglist-core.txt pkglist-devel.txt pkglist-extra.txt pyproject-full.toml

>>>>>>> a691de5 (version-0.0.9)

clean: rootfs
	-rm -f pyproject.toml poetry.lock pyproject-core.toml package.json package-lock.json package-core.json poetry-core.lock package-lock-core.json pkglist-core.txt pkglist-devel.txt pkglist-extra.txt requirements-core.txt
	

<<<<<<< HEAD
clean-all: clean
	-rm -rf node_modules .venv .cache
=======
clean-tags:
	docker images | grep dorgeln/datascience | awk '{system("docker rmi " "'"dorgeln/datascience:"'" $2)}'
>>>>>>> a691de5 (version-0.0.9)

clean-tags:
	docker images | grep dorgeln/datascience | awk '{system("docker rmi " "'"dorgeln/datascience:"'" $2)}'