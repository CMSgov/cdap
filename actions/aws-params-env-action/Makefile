# Makefile for aws-params-env-action
# Requires: node, npm, aws cli (for local SSM testing)

.PHONY: all install build package format format-check lint test run

all: format-check lint test

install:
	npm install

format:
	npm run format

format-check:
	npm run format-check

lint:
	npm run lint

test:
	npm test

test-watch:
	npm test -- --watch

test-coverage:
	npm test -- --coverage

# Builds inside Docker; shadows node_modules so host and container
# binaries never conflict with codebuild. dist/ is written back to host via volume mount.
NODE_IMAGE ?= node:24-alpine

package-docker:
	docker run --rm \
	  -v "$(shell pwd)":/app \
	  -w /app \
	  $(NODE_IMAGE) \
	  sh -c "cp -r /app /build && \
	         cd /build && \
	         npm ci && \
	         npm run package && \
	         rm -rf /app/dist && \
	         cp -r /build/dist /app/dist"
	@echo "dist/ written to $(shell pwd)/dist/"
	@ls -lh dist/

test-docker:
	docker run --rm \
	  -v "$(shell pwd)":/app \
	  -w /app \
	  $(NODE_IMAGE) \
	  sh -c "cp -r /app /build && \
	         cd /build && \
	         npm ci && \
	         npm test"

clean:
	rm -rf dist lib node_modules

PARAMS      ?= SONARQUBE_URL=/sonarqube/url
AWS_REGION  ?= us-east-1
AWS_PROFILE ?= default

run: package-docker
	INPUT_PARAMS="$(PARAMS)" \
	AWS_REGION=$(AWS_REGION) \
	node dist/index.js
