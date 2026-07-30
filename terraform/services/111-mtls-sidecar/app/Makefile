.PHONY: build run down test test-unit clean certs ecr-login push

COMPOSE_FILE := docker-compose.yml

AWS_DEFAULT_REGION ?= us-east-1
ENV                ?= test
SERVICE_NAME       := mtls-sidecar
IMAGE_TAG          ?= $(shell git rev-parse HEAD)
CLUSTER_NAME       := cdap-test-mtls-sidecar

# Only evaluated by targets that use them
AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY   = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com
ECR_REPOSITORY = cdap-$(SERVICE_NAME)
KMS_KEY_ARN    = $(shell aws kms describe-key \
  --key-id alias/cdap-$(ENV) \
  --query KeyMetadata.Arn \
  --output text)


certs:
	mkdir -p certs
	cd certs && \
	openssl req -x509 -newkey rsa:4096 -keyout ca.key -out ca.pem \
	  -days 365 -nodes -subj "/CN=local-ca" && \
	openssl req -newkey rsa:4096 -nodes -keyout server.key -out server.csr \
	  -subj "/CN=localhost" && \
	openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key \
	  -CAcreateserial -out server.crt -days 365 && \
	openssl req -newkey rsa:4096 -nodes -keyout client.key -out client.csr \
	  -subj "/CN=local-client" && \
	openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key \
	  -CAcreateserial -out client.crt -days 365

build:
	docker compose -f $(COMPOSE_FILE) build

run:
	docker compose -f $(COMPOSE_FILE) down --remove-orphans
	docker compose -f $(COMPOSE_FILE) up --build

down:
	docker compose -f $(COMPOSE_FILE) down --remove-orphans

# Run unit tests locally (no Docker needed)
test-unit:
	cd src && go test ./tests/... -v

# Test WITHOUT client cert (should be rejected)
test-no-cert:
	curl -k https://localhost:8443/ || true

# Test WITH client cert (should succeed)
test-mtls:
	curl -k \
	  --cert certs/client.crt \
	  --key certs/client.key \
	  https://localhost:8443/

test-coverage:
	cd src && go test ./tests/... -v \
		-coverprofile=/app/coverage/coverage.out && \
	sed -i 's|mtls-sidecar/||g' /app/coverage/coverage.out && \
	go tool cove-r -xml=/app/coverage/coverage.out -o /app/coverage/coverage.xml

clean:
	docker compose -f $(COMPOSE_FILE) down --rmi all

# -------------------------------------------------------
# AWS / ECR Targets (LOCAL USE ONLY)
# GitHub Actions uses OIDC + secrets for ECR access.
# -------------------------------------------------------

## Authenticate Docker with ECR
ecr-login:
	aws ecr get-login-password --region $(AWS_DEFAULT_REGION) \
	  | docker login --username AWS --password-stdin $(ECR_REGISTRY)

## Build, push image to ECR, and update SSM image tag
push: ecr-login
	@test -n "$(AWS_ACCOUNT_ID)" || (echo "ERROR: Not authenticated" && exit 1)
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	  if [ "$$BRANCH" != "main" ]; then \
	    echo "WARNING: Pushing from branch $$BRANCH (not main)"; \
	    read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1; \
	  fi
	DOCKER_BUILDKIT=1 docker build \
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

