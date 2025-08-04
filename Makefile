# Serverless Recipe AI Makefile

.PHONY: help install-backend install-frontend deploy-infra deploy-backend deploy-frontend deploy-all test clean

# Variables
AWS_REGION ?= us-east-1
ENV ?= dev
TERRAFORM_DIR = infrastructure
BACKEND_DIR = backend
FRONTEND_DIR = frontend

help: ## Display this help message
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install-backend: ## Install backend dependencies
	@echo "Installing backend dependencies..."
	@cd $(BACKEND_DIR) && \
	for dir in */; do \
		if [ -f "$$dir/requirements.txt" ]; then \
			echo "Installing dependencies for $$dir"; \
			cd "$$dir" && pip install -r requirements.txt -t . && cd ..; \
		fi; \
	done

install-frontend: ## Install frontend dependencies
	@echo "Installing frontend dependencies..."
	@cd $(FRONTEND_DIR) && npm install

deploy-infra: ## Deploy infrastructure with Terraform
	@echo "Deploying infrastructure..."
	@cd $(TERRAFORM_DIR) && \
	terraform init && \
	terraform plan -var="environment=$(ENV)" && \
	terraform apply -var="environment=$(ENV)" -auto-approve

deploy-backend: ## Package and deploy Lambda functions
	@echo "Deploying backend functions..."
	@cd $(BACKEND_DIR) && \
	for dir in */; do \
		echo "Packaging $$dir"; \
		cd "$$dir" && \
		zip -r "../$${dir%/}.zip" . -x "*.pyc" "__pycache__/*" "tests/*" && \
		cd ..; \
	done
	@echo "Lambda functions packaged. Deploy using Terraform or AWS CLI."

deploy-frontend: ## Build and deploy frontend
	@echo "Building and deploying frontend..."
	@cd $(FRONTEND_DIR) && \
	npm run build && \
	echo "Frontend built. Deploy to S3 using Terraform or AWS CLI."

deploy-all: deploy-infra deploy-backend deploy-frontend ## Deploy everything

test-backend: ## Run backend tests
	@echo "Running backend tests..."
	@cd $(BACKEND_DIR) && \
	python -m pytest tests/ -v

test-frontend: ## Run frontend tests
	@echo "Running frontend tests..."
	@cd $(FRONTEND_DIR) && npm test

test-integration: ## Run integration tests
	@echo "Running integration tests..."
	@cd tests && python -m pytest integration/ -v

test: test-backend test-frontend ## Run all tests

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@find . -name "*.zip" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete
	@cd $(FRONTEND_DIR) && rm -rf dist/ node_modules/.cache/ 2>/dev/null || true
	@cd $(TERRAFORM_DIR) && rm -rf .terraform/ terraform.tfstate* 2>/dev/null || true

dev-backend: ## Start backend development environment
	@echo "Starting backend development environment..."
	@cd $(BACKEND_DIR) && python -m uvicorn app:app --reload --host 0.0.0.0 --port 8000

dev-frontend: ## Start frontend development server
	@echo "Starting frontend development server..."
	@cd $(FRONTEND_DIR) && npm run dev

format: ## Format code
	@echo "Formatting Python code..."
	@black $(BACKEND_DIR)/ tests/
	@echo "Formatting TypeScript code..."
	@cd $(FRONTEND_DIR) && npm run format

lint: ## Lint code
	@echo "Linting Python code..."
	@flake8 $(BACKEND_DIR)/ tests/
	@echo "Linting TypeScript code..."
	@cd $(FRONTEND_DIR) && npm run lint

security-scan: ## Run security scans
	@echo "Running security scans..."
	@bandit -r $(BACKEND_DIR)/
	@cd $(FRONTEND_DIR) && npm audit

local-stack: ## Start LocalStack for local development
	@echo "Starting LocalStack..."
	@docker-compose -f docker-compose.localstack.yml up -d

stop-local-stack: ## Stop LocalStack
	@echo "Stopping LocalStack..."
	@docker-compose -f docker-compose.localstack.yml down

setup-dev: install-backend install-frontend ## Setup development environment
	@echo "Development environment setup complete!"

destroy-infra: ## Destroy infrastructure (use with caution!)
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TERRAFORM_DIR) && terraform destroy -var="environment=$(ENV)" -auto-approve; \
	fi
