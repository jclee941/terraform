.PHONY: plan apply verify lint backup fmt validate init drift-check

# Flat NNN-SVC convention: SVC=100-pve (default)
# 1-255 = internal infra (192.168.50.x), 300+ = external (cloudflare, aws...)
SVC ?= 100-pve
TF_DIR := $(SVC)

## Terraform targets

init: ## Initialize Terraform (SVC=100-pve)
	cd $(TF_DIR) && terraform init

plan: ## Create Terraform plan (SVC=100-pve)
	cd $(TF_DIR) && terraform plan -out=tfplan

apply: ## Apply Terraform plan (SVC=100-pve)
	cd $(TF_DIR) && terraform apply tfplan

fmt: ## Format all Terraform files
	find . -maxdepth 1 -type d -name '[0-9]*' -exec terraform fmt -recursive {} +
	terraform fmt -recursive modules/

validate: ## Validate Terraform configuration (SVC=100-pve)
	cd $(TF_DIR) && terraform init -backend=false && terraform validate

## Linting targets

lint: lint-yaml lint-tf lint-shell ## Run all linters

lint-yaml: ## Lint YAML files
	yamllint -c .yamllint.yml .

lint-tf: ## Check Terraform formatting
	find . -maxdepth 1 -type d -name '[0-9]*' -exec terraform fmt -check -recursive {} +
	terraform fmt -check -recursive modules/

lint-shell: ## Lint shell scripts
	find scripts/ -name '*.sh' -exec shellcheck --severity=warning {} +

## Verification & Backup

verify: ## Run production verification
	./scripts/production_verification_v2.sh

backup: ## Create encrypted Terraform state backup
	./scripts/backup-tfstate.sh

drift-check: ## Check for Terraform drift
	./scripts/terraform-drift-check.sh

## OpenCode Config

VARIANT ?= copilot

deploy-opencode: ## Deploy OpenCode config to VM 200 (VARIANT=copilot)
	./200-oc/opencode/deploy.sh $(VARIANT)

deploy-opencode-dry: ## Dry-run OpenCode deploy (VARIANT=copilot)
	./200-oc/opencode/deploy.sh $(VARIANT) --dry-run

gen-opencode: ## Generate OpenCode config only (VARIANT=copilot)
	./200-oc/opencode/deploy.sh $(VARIANT) --gen

## Pre-commit

pre-commit-install: ## Install pre-commit hooks
	pre-commit install

pre-commit-run: ## Run pre-commit on all files
	pre-commit run --all-files

## Help

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
