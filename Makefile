ENV ?= prod
TFVARS := envs/$(ENV)/terraform.tfvars

.DEFAULT_GOAL := help

.PHONY: help init fmt fmt-check validate test plan plan-json apply output destroy verify security clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

init: ## Initialize Terraform and download providers
	terraform init

fmt: ## Format all Terraform files
	terraform fmt -recursive

fmt-check: ## Fail if files are not formatted
	terraform fmt -check -recursive

validate: init ## Validate configuration
	terraform validate

test: init ## Run native Terraform tests with mocked providers
	terraform test

plan: init ## Create a saved plan; exit code 2 means changes are pending
	terraform plan -var-file=$(TFVARS) -out=tfplan -detailed-exitcode || [ $$? -eq 2 ]

plan-json: plan ## Render the saved plan as JSON for policy checks
	terraform show -json tfplan > plan.json

apply: ## Apply exactly the saved plan
	@test -f tfplan || { echo "No tfplan found. Run 'make plan' first."; exit 1; }
	terraform apply tfplan

output: ## Show outputs
	terraform output

destroy: ## Destroy infrastructure; requires deletion_protection = false
	terraform destroy -var-file=$(TFVARS)

verify: ## Run the local agent verification gate
	./scripts/verify.sh

security: ## Run optional security scanners when installed
	./scripts/security.sh

clean: ## Remove local Terraform artifacts
	rm -rf .terraform .terraform.lock.hcl tfplan plan.json crash.log
