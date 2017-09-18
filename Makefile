##
## Golang application Makefile
##

SHELL      = /bin/bash
# application name
PRG        ?= teleproxy
# Config filename, hardcoded in docker-compose
CFG         = .env
# docker compose name
SERVICE     = $(PRG)
# Where are sources
CMDS        = $(PRG)

DIRDIST   ?= dist
ALLARCH   ?= "linux/amd64"
# linux/386 windows/amd64 darwin/386"

# Local run vars
LOG        ?= $(PRGBIN).log
PID        ?= $(PRGBIN).pid

# Docker imege build vars
# docker-compose version
DC_VER        = 1.14.0
# golang version
GO_VER        = 1.9.0-alpine3.6

# Dcape vars
# container prefix
PROJECT_NAME ?= elfire
# dcape net connect to
DCAPE_NET    ?= dcape_default
# used by deploy system
DOCKER_BIN   ?= docker

# ------------------------------------------------------------------------------
# config vars

# Telegram bot token
BOT_TOKEN        ?= bot_token

# Telegram group ID (without -)
BOT_GROUP        ?= group_id

# ------------------------------------------------------------------------------

-include $(CFG)
export

# ------------------------------------------------------------------------------

.PHONY: all build clean lint docker up down build-docker start-hook update restart end run status dc help
.PHONY: all run ver buildall clean dist link vet

##
## Available targets are:
##

build:
	for d in $(CMDS) ; do pushd cmd/$$d > /dev/null && make build && popd > /dev/null ; done

clean:
	for d in $(CMDS) ; do pushd cmd/$$d > /dev/null && make clean && popd > /dev/null ; done

## Build docker image if none
docker:
	@$(MAKE) -s dc CMD="build $(SERVICE)" || echo ""

## Rebuild docker image
build-docker:
	@$(MAKE) -s dc CMD="build --no-cache --force-rm"

## Start docker container
up:
	@$(MAKE) -s dc CMD="up -d --force-recreate $(SERVICE)" || echo ""

## Stop and remove docker container
down:
	@$(MAKE) -s dc CMD="rm -f -s $(SERVICE)" || echo ""

# ------------------------------------------------------------------------------
# webhook commands

start-hook: up

update: up

stop: down

# ------------------------------------------------------------------------------
# Local run without docker

restart: end run

end:
	@echo "*** $@ ***"
	@[ -f $(PID) ] && kill -SIGTERM `cat $(PID)` || echo "No pidfile"
	@[ -f $(PID) ] && rm $(PID) || true

run: build
	@echo "*** $@ ***"
	@nohup cmd/$(PRG)/$(PRG) --log_level debug --group $$BOT_GROUP --token $$BOT_TOKEN >>$(LOG) 2>&1 & echo $$! > $(PID)
	@echo "Started, pid=`cat $(PID)`"

status:
	@echo "*** $@ ***"
	@[ -f $(PID) ] && kill -0 `cat $(PID)` && echo "running" || echo "No such process"

# ------------------------------------------------------------------------------
# Distro ops

## build app for all platforms
buildall:
	@pushd cmd/$(PRG) > /dev/null
	@for a in "$(ALLARCH)" ; do \
	  echo "** $${a%/*} $${a#*/}" ; \
	  P=$(PRG)_$${a%/*}_$${a#*/} ; \
	  [ "$${a%/*}" == "windows" ] && P=$$P.exe ; \
	  GOOS=$${a%/*} GOARCH=$${a#*/} $(MAKE) -s build ; \
	@done
	@popd > /dev/null

## create disro files
dist: clean-dist buildall
	@echo "*** $@ ***"
	@[ -d $(DIRDIST) ] || mkdir $(DIRDIST) ; \
	@pushd cmd/$(PRG) > /dev/null
	sha256sum $(PRG)* > ../../$(DIRDIST)/SHA256SUMS ; \
	@for a in "$(ALLARCH)" ; do \
	  echo "** $${a%/*} $${a#*/}" ; \
	  P=$(PRG)_$${a%/*}_$${a#*/} ; \
	  [ "$${a%/*}" == "windows" ] && P1=$$P.exe || P1=$$P ; \
	  zip "../../$(DIRDIST)/$$P.zip" "$$P1" README.md ; \
	done
	@popd > /dev/null

## clean generated files
clean-dist:
	@echo "*** $@ ***"
	@pushd cmd/$(PRG) > /dev/null
	@for a in "$(ALLARCH)" ; do \
	  P=$(PRG)_$${a%/*}_$${a#*/} ; \
	  [ "$${a%/*}" == "windows" ] && P=$$P.exe ; \
	  [ -f $$P ] && rm $$P || true ; \
	done ; \
	@popd > /dev/null
	@[ -d $(DIRDIST) ] && rm -rf $(DIRDIST) || true

# ------------------------------------------------------------------------------
# Setup targets

# Файл .env
define CONFIG_DEF
# config file, generated by make $(CFG)

# Bot token
BOT_TOKEN=$(APP_SITE)

# Group proxy messages for
BOT_GROUP=$(DB_NAME)

# Commands archive URL
CMD_URL=

# dcape network connect to, must be set in .env
DCAPE_NET=$(DCAPE_NET)

endef
export CONFIG_DEF

$(CFG):
	@echo "*** $@ ***"
	@[ -f $@ ] || echo "$$CONFIG_DEF" > $@

# ------------------------------------------------------------------------------

# $$PWD используется для того, чтобы текущий каталог был доступен в контейнере по тому же пути
# и относительные тома новых контейнеров могли его использовать
## run docker-compose
dc: docker-compose.yml
	@$$DOCKER_BIN run --rm  -i \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $$PWD:$$PWD \
  -w $$PWD \
  --env=golang_version=$$GO_VER \
  docker/compose:$$DC_VER \
  -p $$PROJECT_NAME \
  $(CMD)

all: help

help:
	@grep -A 1 "^##" Makefile | less

##
## Press 'q' for exit
##
