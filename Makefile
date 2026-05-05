# Serverless Recipe AI Makefile

.PHONY: help install-backend install-test deploy-infra deploy-backend test test-backend lint format security-scan clean destroy-infra

# Variables
AWS_REGION ?= us-east-1
ENV ?= dev
TERRAFORM_DIR = infrastructure
BACKEND_DIR = backend
LAMBDA_DIR = backend/generate-recipe

help: ## Display this help message
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install-backend: ## Install backend (Lambda) dependencies into the package directory
	@echo "Installing backend dependencies..."
	@pip install -r $(LAMBDA_DIR)/requirements.txt -t $(LAMBDA_DIR)

install-test: ## Install test dependencies
	@pip install -r tests/requirements.txt

deploy-infra: ## Deploy infrastructure with Terraform
	@echo "Deploying infrastructure..."
	@cd $(TERRAFORM_DIR) && \
		terraform init && \
		terraform plan -var="environment=$(ENV)" && \
		terraform apply -var="environment=$(ENV)"

deploy-backend: ## Package the Lambda (Terraform handles the upload)
	@echo "Packaging Lambda function..."
	@cd $(LAMBDA_DIR) && zip -r ../generate-recipe.zip . -x "*.pyc" "__pycache__/*" "tests/*"
	@echo "Lambda packaged. Run 'make deploy-infra' to upload via Terraform."

test-backend: install-test ## Run backend tests
	@pytest tests/ -v

test: test-backend ## Run all tests

format: ## Format Python code
	@black $(BACKEND_DIR)/ tests/

lint: ## Lint Python code
	@flake8 $(BACKEND_DIR)/ tests/

security-scan: ## Run Bandit on Python sources
	@bandit -r $(BACKEND_DIR)/

clean: ## Clean build artifacts
	@find . -name "*.zip" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete
	@cd $(TERRAFORM_DIR) && rm -rf .terraform/ terraform.tfstate* 2>/dev/null || true

destroy-infra: ## Destroy infrastructure (use with caution!)
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TERRAFORM_DIR) && terraform destroy -var="environment=$(ENV)"; \
	fi
