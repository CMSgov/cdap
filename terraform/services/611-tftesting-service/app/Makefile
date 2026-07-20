.PHONY: build up down logs test shell clean

# Build the app image
build:
	docker compose build

# Start the full stack (app + datadog agent)
up:
	docker compose up

# Stop and remove containers
down:
	docker compose down

# Tail logs
logs:
	docker compose logs -f

# Tail app logs only
logs-app:
	docker compose logs -f app

# Tail datadog agent logs only
logs-agent:
	docker compose logs -f datadog-agent

# Run tests inside the container
test:
	docker compose run --rm app python -m pytest tests/ -v

# Open a shell in the app container
shell:
	docker compose run --rm app /bin/sh

# Remove containers, images, and volumes
clean:
	docker compose down --rmi local --volumes --remove-orphans

AWS_DEFAULT_REGION     ?= us-east-1
ENV            ?= test
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
SERVICE_NAME   := tftesting-service
ECR_REGISTRY   := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com
ECR_REPOSITORY := cdap-$(SERVICE_NAME)
IMAGE_TAG      ?= $(shell git rev-parse HEAD)
KMS_KEY_ALIAS  ?= alias/cdap-$(ENV)

requirements:
	docker run --rm \
	  -v $(PWD):/app \
	  -w /app \
	  python:3.13-slim \
	  /bin/sh -c "pip install --quiet pip-tools && pip-compile --generate-hashes requirements.in --output-file requirements.txt"
	@echo "requirements.txt updated with hashes"

# -------------------------------------------------------
# ECR push targets are for LOCAL USE ONLY.
# GitHub Actions uses OIDC + secrets for ECR access.
# -------------------------------------------------------

ecr-login:
	aws ecr get-login-password --region $(AWS_DEFAULT_REGION) \
	  | docker login --username AWS --password-stdin $(ECR_REGISTRY)

push: ecr-login
	@test -n "$(AWS_ACCOUNT_ID)" || (echo "ERROR: Not authenticated" && exit 1)
	@docker build \
	  -t $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG) \
	  -f Dockerfile \
	  .
	@docker push $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG)
	@aws ssm put-parameter \
	  --name "/cdap/$(ENV)/nonsensitive/$(SERVICE_NAME)/image-tag" \
	  --value "$(IMAGE_TAG)" \
	  --type SecureString \
	  --key-id "$(KMS_KEY_ALIAS)" \
	  --overwrite
	@echo "Pushed $(SERVICE_NAME):$(IMAGE_TAG)"
