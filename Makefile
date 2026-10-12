.PHONY: build test stress

prep-local:
	mkdir -p ~/.its-log/data

build: prep-local
	cd api ; go build -o its-log

container-api: prep-local
	docker build -t itslog-app -f ops/containers/itslog/Dockerfile .

container-e2e: prep-local
	docker build -t itslog-e2e -f ops/containers/e2e/Dockerfile .


e2e: container-api container-e2e
	docker compose \
	-f ops/containers/docker-compose-e2e.yaml \
	up \
	--abort-on-container-exit

test:
	echo hi