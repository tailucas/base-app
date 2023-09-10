APP := base_app
DOCKER_APP := base-app
USER_ID := 999
GROUP_ID := $(shell getent group docker | cut -f3 -d ':')

all: help

help:
	@echo "Depends on 1Password Connect Server: https://developer.1password.com/docs/connect/get-started"

pydeps:
	curl -sSL https://install.python-poetry.org | python3 -
	@echo "Now add poetry to your PATH and run 'poetry install'."

user:
	id $(USER_ID) || (sudo useradd -r -u $(USER_ID) -g $(GROUP_ID) app && sudo usermod -a -G $(GROUP_ID) -u $(USER_ID) app)
	mkdir -p ./data/
	sudo chown $(USER_ID):$(GROUP_ID) ./data/
	sudo chmod 755 ./data/
	sudo chmod g+rws ./data/

setup: docker-compose.template
	@echo "Generating docker-compose.yml"
	cat docker-compose.template | sed "s~__DOCKER_HOSTNAME__~$(DOCKER_APP)~g" > docker-compose.template2
	poetry run python ./cred_tool ENV.$(APP) $(APP) | poetry run python ./yaml_interpol services/app/environment docker-compose.template2 > docker-compose-build.yml
	poetry run python ./cred_tool ENV.$(APP) build | poetry run python ./yaml_interpol services/app/build/args docker-compose-build.yml > docker-compose.yml
	rm -f docker-compose-build.yml
	rm -f docker-compose.template2

build:
	sudo rm -f ./data/app-std* ./data/cron-std* ./data/supervisor.sock
	docker-compose build --progress plain

run:
	docker-compose up

rund:
	docker-compose up -d

runl:
	poetry run python ./cred_tool ENV.$(APP) $(APP) | jq -r '. | to_entries[] | [.key,.value] | @tsv' | tr '\t' '=' | sed 's/=\(.*\)/="\1"/' > .env
	poetry run app

connect:
	./connect_to_app.sh $(DOCKER_APP)

clean:
	rm docker-compose.yml

.PHONY: all help setup run connect clean pydeps
