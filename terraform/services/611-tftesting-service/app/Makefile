.PHONY: build up down logs logs-app logs-agent test test-coverage test-local \
        shell clean requirements ecr-login push scale scale-up scale-down

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

# run tests locally
test-local:
	python -m pytest src/tests/ -v

# Run tests inside the container
test:
	docker compose run --rm app pytest src/tests/ -v

test-coverage-report:
	docker compose run --rm \
	  -e DD_TRACE_ENABLED=false \
	  app /bin/sh -c "pytest src/tests/ \
	    --cov=src \
	    --cov-report=term-missing \
	    --cov-report=xml:/app/coverage/coverage.xml"

# Open a shell in the app container
shell:
	docker compose run --rm app /bin/sh

# Remove containers, images, and volumes
clean:
	docker compose down --rmi local --volumes --remove-orphans


AWS_DEFAULT_REGION ?= us-east-1
ENV                ?= test
SERVICE_NAME       := tftesting-service
IMAGE_TAG          ?= $(shell git rev-parse HEAD)
CLUSTER_NAME := cdap-test-tftesting
# only evaluated by targets that use them
AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY   = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com
ECR_REPOSITORY = cdap-$(SERVICE_NAME)
KMS_KEY_ARN    = $(shell aws kms describe-key \
  --key-id alias/cdap-$(ENV) \
  --query KeyMetadata.Arn \
  --output text)

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

DESIRED_COUNT ?= 1

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

scale-up: DESIRED_COUNT = 1
scale-up: scale

scale-down: DESIRED_COUNT = 0
scale-down: scale