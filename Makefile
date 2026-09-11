SHELL := /bin/bash
LAB ?= 01-api-lambda-dynamodb
LAB_DIR := labs/$(LAB)
TOFU_DIR := $(LAB_DIR)/infra/tofu

.PHONY: help doctor start stop status build init validate plan deploy outputs test destroy logs clean

help:
	@printf '%s\n' 'Targets: doctor start stop status build init validate plan deploy outputs test destroy logs clean'

doctor:
	@command -v docker >/dev/null || { echo 'Docker is required.'; exit 1; }
	@docker info >/dev/null || { echo 'Docker daemon is not available.'; exit 1; }
	@command -v tofu >/dev/null || { echo 'OpenTofu is required (brew install opentofu).'; exit 1; }
	@command -v curl >/dev/null || { echo 'curl is required.'; exit 1; }
	@command -v zip >/dev/null || { echo 'zip is required.'; exit 1; }
	@echo 'Environment check passed.'

start:
	docker compose up -d
	@until curl --silent --fail http://localhost:4566/_floci/health >/dev/null; do sleep 1; done
	@echo 'Floci is ready at http://localhost:4566.'

stop:
	docker compose down

status:
	docker compose ps

build:
	@mkdir -p $(LAB_DIR)/dist
	@rm -f $(LAB_DIR)/dist/function.zip
	@cd $(LAB_DIR)/src && zip -X -q -j ../dist/function.zip index.mjs

init: build
	cd $(TOFU_DIR) && tofu init

validate: init
	cd $(TOFU_DIR) && tofu validate

plan: init
	cd $(TOFU_DIR) && tofu plan -refresh=false -out=tfplan

deploy: start init
	cd $(TOFU_DIR) && tofu apply -refresh=false -auto-approve

outputs:
	cd $(TOFU_DIR) && tofu output

test:
	cd $(LAB_DIR) && API_URL="$$(cd infra/tofu && tofu output -raw api_url)" TABLE_NAME="$$(cd infra/tofu && tofu output -raw table_name)" node tests/integration/api.test.mjs

destroy:
	cd $(TOFU_DIR) && tofu destroy -auto-approve

logs:
	docker compose logs --tail=200 floci

clean:
	rm -rf $(LAB_DIR)/dist $(TOFU_DIR)/.terraform $(TOFU_DIR)/.terraform.lock.hcl $(TOFU_DIR)/tfplan
