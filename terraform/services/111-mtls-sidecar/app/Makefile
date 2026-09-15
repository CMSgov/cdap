.PHONY: build run down test-unit test-no-cert test-mtls test-coverage clean certs ecr-login push buildx-setup inspect-image

COMPOSE_FILE := docker-compose.yml
PLATFORM     := linux/arm64

AWS_DEFAULT_REGION ?= us-east-1
ENV                ?= test
SERVICE_NAME       := mtls-sidecar
IMAGE_TAG          ?= $(shell git rev-parse HEAD)
CLUSTER_NAME       := cdap-test-mtls-sidecar

AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY   = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com
ECR_REPOSITORY = cdap-$(SERVICE_NAME)
KMS_KEY_ARN    = $(shell aws kms describe-key \
  --key-id alias/cdap-$(ENV) \
  --query KeyMetadata.Arn \
  --output text)

buildx-setup:
	docker buildx create --name multiarch --use --bootstrap || docker buildx use multiarch
certs:
	mkdir -p certs
	cd certs && \
	openssl req -x509 -newkey rsa:4096 -keyout ca.key -out ca.pem \
	  -days 365 -nodes -subj "/CN=local-ca" && \
	openssl req -newkey rsa:4096 -nodes -keyout server.key -out server.csr \
	  -subj "/CN=localhost" && \
	printf "subjectAltName=DNS:localhost,IP:127.0.0.1" > san.cnf && \
	openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key \
	  -CAcreateserial -out server.crt -days 365 \
	  -extfile san.cnf && \
	rm -f san.cnf && \
	openssl req -newkey rsa:4096 -nodes -keyout client.key -out client.csr \
	  -subj "/CN=local-client" && \
	openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key \
	  -CAcreateserial -out client.crt -days 365

# Uses provenance false to ensure compatibility
build:
	docker buildx build \
	  --platform $(PLATFORM) \
	  --provenance=false \
	  --load \
	  -t $(SERVICE_NAME):local \
	  -f Dockerfile \
	  .

run:
	docker compose -f $(COMPOSE_FILE) down --remove-orphans
	docker compose -f $(COMPOSE_FILE) up --build

down:
	docker compose -f $(COMPOSE_FILE) down --remove-orphans

test-unit:
	cd src && go test ./tests/... -v

test-health:
	curl -f http://localhost:8081/health && echo "✅ health check passed" || echo "❌ health check failed"

test-no-cert:
	curl -k https://localhost:8443/ || true

test-mtls:
	curl -k \
	  --cert certs/client.crt \
	  --key certs/client.key \
	  https://localhost:8443/

test-coverage:
	cd src && go test ./tests/... -v \
		-coverprofile=/app/coverage/coverage.out && \
	sed -i 's|mtls-sidecar/||g' /app/coverage/coverage.out && \
	go tool cover -html=/app/coverage/coverage.out -o /app/coverage/coverage.xml

test-local: test-health test-no-cert test-mtls

clean:
	docker compose -f $(COMPOSE_FILE) down --rmi all

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
	docker buildx build \
	  --platform $(PLATFORM) \
	  --provenance=false \
	  -t $(ECR_REGISTRY)/$(ECR_REPOSITORY):$(IMAGE_TAG) \
	  -f Dockerfile \
	  --push \
	  .
	@aws ssm put-parameter \
	  --name "/cdap/$(ENV)/nonsensitive/$(SERVICE_NAME)/image-tag" \
	  --value "$(IMAGE_TAG)" \
	  --type SecureString \
	  --key-id "$(KMS_KEY_ARN)" \
	  --overwrite
	@echo "✅ Pushed $(SERVICE_NAME):$(IMAGE_TAG) to $(ENV)"
