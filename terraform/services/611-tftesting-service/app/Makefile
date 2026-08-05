.PHONY: build up down restart logs logs-app logs-agent \
        test test-coverage test-local shell clean requirements \
        ecr-login push scale scale-up scale-down

# -------------------------------------------------------
# Configuration
# -------------------------------------------------------

COMPOSE_FILE       := docker-compose.yml
AWS_DEFAULT_REGION ?= us-east-1
ENV                ?= test
SERVICE_NAME       := tftesting-service
IMAGE_TAG          ?= $(shell git rev-parse HEAD)
CLUSTER_NAME       := cdap-test-tftesting

# Only evaluated by targets that use them
AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY   = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com
ECR_REPOSITORY = cdap-$(SERVICE_NAME)
KMS_KEY_ARN    = $(shell aws kms describe-key \
  --key-id alias/cdap-$(ENV) \
  --query KeyMetadata.Arn \
  --output text)

# -------------------------------------------------------
# Local Docker Compose targets
# -------------------------------------------------------

## Build the app image
build:
	docker compose -f $(COMPOSE_FILE) build

## Start the full stack (stops any running containers first)
up:
	docker compose -f $(COMPOSE_FILE) down --remove-orphans
	docker compose -f $(COMPOSE_FILE) up --build

## Stop and remove containers
down:
	docker compose -f $(COMPOSE_FILE) down --remove-orphans

## Restart the full stack
restart: down up

## Tail all logs
logs:
	docker compose -f $(COMPOSE_FILE) logs -f

## Tail app logs only
logs-app:
	docker compose -f $(COMPOSE_FILE) logs -f app

## Tail datadog agent logs only
logs-agent:
	docker compose -f $(COMPOSE_FILE) logs -f datadog-agent

## Open a shell in the app container
shell:
	docker compose -f $(COMPOSE_FILE) run --rm app /bin/sh

## Remove containers, images, and volumes
clean:
	docker compose -f $(COMPOSE_FILE) down --rmi local --volumes --remove-orphans

# -------------------------------------------------------
# Test targets
# -------------------------------------------------------

## Run tests locally (no Docker)
test-local:
	python -m pytest src/tests/ -v

## Run tests inside a fresh container (rebuilds first to pick up code changes)
test:
	docker compose -f $(COMPOSE_FILE) down --remove-orphans
	docker compose -f $(COMPOSE_FILE) build
	docker compose -f $(COMPOSE_FILE) run --rm \
	  -e DD_TRACE_ENABLED=false \
	  app pytest src/tests/ -v

## Run tests with coverage report (rebuilds first)
test-coverage:
	docker compose -f $(COMPOSE_FILE) down --remove-orphans
	docker compose -f $(COMPOSE_FILE) build
	docker compose -f $(COMPOSE_FILE) run --rm \
	  -e DD_TRACE_ENABLED=false \
	  app pytest src/tests/ \
	    --cov=src \
	    --cov-report=term-missing \
	    --cov-report=xml:/app/coverage/coverage.xml

# -------------------------------------------------------
# Dependency management
# -------------------------------------------------------

## Recompile requirements.txt with hashes from requirements.in
requirements:
	docker run --rm \
	  -v $(PWD):/app \
	  -w /app \
	  python:3.13-slim \
	  /bin/sh -c "pip install --quiet pip-tools && \
	    pip-compile --generate-hashes requirements.in \
	    --output-file requirements.txt"
	@echo "✅ requirements.txt updated with hashes"

# -------------------------------------------------------
# ECR targets — LOCAL USE ONLY
# GitHub Actions uses OIDC + secrets for ECR access.
# -------------------------------------------------------

## Authenticate Docker with ECR
ecr-login:
	aws ecr get-login-password --region $(AWS_DEFAULT_REGION) \
	  | docker login --username AWS --password-stdin $(ECR_REGISTRY)

## Build, tag, push image to ECR and update SSM image-tag parameter
push: ecr-login
	@test -n "$(AWS_ACCOUNT_ID)" || (echo "ERROR: Not authenticated" && exit 1)
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	  if [ "$$BRANCH" != "main" ]; then \
	    echo "WARNING: Pushing from branch $$BRANCH (not main)"; \
	    read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1; \
	  fi
	DOCKER_BUILDKIT=0 docker build \
	  -t $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG) \
	  -f Dockerfile \
	  .
	docker push $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG)
	@aws ssm put-parameter \
	  --name "/cdap/$(ENV)/nonsensitive/$(SERVICE_NAME)/image-tag" \
	  --value "$(IMAGE_TAG)" \
	  --type SecureString \
	  --key-id "$(KMS_KEY_ARN)" \
	  --overwrite
	@echo "✅ Pushed $(SERVICE_NAME):$(IMAGE_TAG) to $(ENV)"

# -------------------------------------------------------
# ECS scaling targets
# -------------------------------------------------------

DESIRED_COUNT ?= 1

## Scale ECS service to DESIRED_COUNT tasks
scale:
	@test -n "$(AWS_ACCOUNT_ID)" || (echo "ERROR: Not authenticated" && exit 1)
	@echo "Scaling cdap-$(ENV)-$(SERVICE_NAME) to $(DESIRED_COUNT) tasks..."
	@aws ecs update-service \
	  --cluster "$(CLUSTER_NAME)" \
	  --service "cdap-$(ENV)-$(SERVICE_NAME)" \
	  --desired-count $(DESIRED_COUNT) \
	  > /dev/null
	@echo "Waiting for service to stabilize..."
	@aws ecs wait services-stable \
	  --cluster "$(CLUSTER_NAME)" \
	  --services "cdap-$(ENV)-$(SERVICE_NAME)"
	@echo "✅ cdap-$(ENV)-$(SERVICE_NAME) scaled to $(DESIRED_COUNT) tasks"

## Scale ECS service up to 1 task
scale-up: DESIRED_COUNT = 1
scale-up: scale

## Scale ECS service down to 0 tasks
scale-down: DESIRED_COUNT = 0
scale-down: scale
