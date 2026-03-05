.PHONY: plan apply verify lint backup fmt validate init drift-check test test-unit test-integration test-workspace docs pre-commit-install pre-commit-run setup help

# Flat NNN-SVC convention: SVC=100-pve (default)
# 1-255 = internal infra (192.168.50.x), 300+ = external (cloudflare, aws...)
# Accepts full paths (100-pve) or short aliases (pve, grafana, elk, etc.)
SVC ?= 100-pve

# Workspace alias map: short name → directory path
# App workspaces with nested terraform/ dirs resolve automatically
ALIAS_pve        := 100-pve
ALIAS_runner     := 101-runner
ALIAS_traefik    := 102-traefik/terraform
ALIAS_grafana    := 104-grafana/terraform
ALIAS_elk        := 105-elk/terraform
ALIAS_glitchtip  := 106-glitchtip
ALIAS_supabase   := 107-supabase
ALIAS_archon     := 108-archon/terraform
ALIAS_mcphub     := 112-mcphub
ALIAS_synology   := 215-synology
ALIAS_youtube    := 220-youtube
ALIAS_cloudflare := 300-cloudflare
ALIAS_github     := 301-github

ALIAS_slack      := 320-slack

# Resolve alias: if ALIAS_$(SVC) is defined, use it; otherwise use SVC as-is
TF_DIR := $(or $(ALIAS_$(SVC)),$(SVC))

# Validate TF_DIR exists before running terraform commands
define check_svc_dir
	@if [ ! -d "$(TF_DIR)" ]; then \
		echo "Error: workspace directory '$(TF_DIR)' does not exist."; \
		echo "Available workspaces:"; \
		echo "  Direct: $$(ls -d [0-9]*/ | tr -d '/' | tr '\n' ' ')"; \
		echo "  Aliases: pve runner traefik grafana elk glitchtip supabase archon mcphub synology youtube cloudflare github slack"; \
		exit 1; \
	fi
endef

## Terraform targets

init: ## Initialize Terraform (SVC=100-pve)
	$(check_svc_dir)
	cd $(TF_DIR) && terraform init

plan: ## Create Terraform plan (SVC=100-pve)
	$(check_svc_dir)
	cd $(TF_DIR) && terraform plan -out=tfplan

apply: ## Apply Terraform plan — DISABLED (use CI/CD)
	@echo '\033[31mERROR: Manual apply is disabled. Deploy via CI/CD:\033[0m'
	@echo '  Push to master branch to trigger automated apply.'
	@echo '  See: https://github.com/qws941/terraform/actions'
	@exit 1

fmt: ## Format all Terraform files
	find . -maxdepth 1 -type d -name '[0-9]*' -exec terraform fmt -recursive {} +
	terraform fmt -recursive modules/

validate: ## Validate Terraform configuration (SVC=100-pve)
	$(check_svc_dir)
	cd $(TF_DIR) && terraform init -backend=false && terraform validate

## Setup

setup: ## Load local credentials from 1Password
	@printf "Load 1Password credentials into current shell:\n"
	@printf "  source scripts/setup-local-env.sh\n\n"
	@printf "To persist credentials to .env.local:\n"
	@printf "  source scripts/setup-local-env.sh --save\n\n"
	@printf "To validate only:\n"
	@printf "  source scripts/setup-local-env.sh --check\n"

## Linting targets

lint: lint-yaml lint-tf lint-shell lint-tflint ## Run all linters

lint-yaml: ## Lint YAML files
	yamllint -c .yamllint.yml .

lint-tf: ## Check Terraform formatting
	find . -maxdepth 1 -type d -name '[0-9]*' -exec terraform fmt -check -recursive {} +
	terraform fmt -check -recursive modules/

lint-shell: ## Lint shell scripts
	find scripts/ -name '*.sh' -exec shellcheck --severity=warning {} +

lint-tflint: ## Run tflint on all workspaces
	@command -v tflint >/dev/null 2>&1 || { echo "tflint not installed. Install: brew install tflint"; exit 1; }
	@for dir in $(shell find . -maxdepth 1 -type d -name '[0-9]*'); do \
		echo "==> tflint $$dir"; \
		tflint --chdir=$$dir --config=$(CURDIR)/.tflint.hcl 2>&1 || true; \
	done
	@echo "==> tflint modules/"
	@tflint --chdir=modules/ --config=$(CURDIR)/.tflint.hcl 2>&1 || true

security: lint-tflint ## Run security scan (tflint + checkov) locally
	@echo ''
	@echo '==> Running Checkov...'
	@command -v checkov >/dev/null 2>&1 || { echo "checkov not installed. Install: pip install checkov"; exit 1; }
	@checkov --directory . --framework terraform --quiet --compact \
		--skip-path .archive --skip-path data --skip-path tests --skip-path 100-pve/configs \
		--skip-check CKV_TF_1 || true

## Testing

test: ## Run all Terraform tests (module + integration + workspace)
	cd tests/modules/proxmox && terraform init -backend=false && terraform test
	cd tests/modules/shared && terraform init -backend=false && terraform test
	cd tests/integration && terraform init -backend=false && terraform test
	cd tests/workspaces/pve && terraform init -backend=false && terraform test
	cd tests/workspaces/cloudflare && terraform init -backend=false && terraform test
	cd tests/workspaces/grafana && terraform init -backend=false && terraform test
	cd tests/workspaces/elk && terraform init -backend=false && terraform test
	cd tests/workspaces/slack && terraform init -backend=false && terraform test


test-unit: ## Run unit tests only
	cd tests/modules/proxmox && terraform init -backend=false && terraform test
	cd tests/modules/shared && terraform init -backend=false && terraform test

test-integration: ## Run integration tests only
	cd tests/integration && terraform init -backend=false && terraform test

test-workspace: ## Run workspace validation tests only
	cd tests/workspaces/pve && terraform init -backend=false && terraform test
	cd tests/workspaces/cloudflare && terraform init -backend=false && terraform test
	cd tests/workspaces/grafana && terraform init -backend=false && terraform test
	cd tests/workspaces/elk && terraform init -backend=false && terraform test
	cd tests/workspaces/slack && terraform init -backend=false && terraform test


## Verification & Backup

verify: ## Run production verification
	go run ./scripts/production-verification.go

backup: ## Create encrypted Terraform state backup
	go run ./scripts/backup-tfstate.go

drift-check: ## Check for Terraform drift — DISABLED (use CI/CD)
	@echo '\033[31mERROR: Local drift-check is disabled. Use GitHub Actions:\033[0m'
	@echo '  Drift detection runs automatically Mon-Fri 00:00 UTC.'
	@echo '  Manual trigger: gh workflow run terraform-drift.yml'
	@echo '  See: https://github.com/qws941/terraform/actions/workflows/terraform-drift.yml'
	@exit 1

## Pre-commit

pre-commit-install: ## Install pre-commit hooks
	pre-commit install

pre-commit-run: ## Run pre-commit on all files
	pre-commit run --all-files

## Documentation

docs: ## Generate module README.md via terraform-docs
	@command -v terraform-docs >/dev/null 2>&1 || { echo "terraform-docs not installed. Install: brew install terraform-docs"; exit 1; }
	@for dir in $(shell find modules/ -mindepth 2 -maxdepth 2 -type f -name 'main.tf' -exec dirname {} \;); do \
		echo "==> terraform-docs $$dir"; \
		terraform-docs markdown table --output-file README.md --output-mode inject $$dir 2>&1 || true; \
	done

## Help

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
