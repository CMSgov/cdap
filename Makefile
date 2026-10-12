.PHONY: build test stress

prep-local:
	mkdir -p ~/.its-log/data

build: prep-local
	cd api ; go build -o its-log .

container-api: prep-local
	docker build -t itslog-api -f ops/containers/itslog/Dockerfile .

container-e2e: prep-local
	docker build -t itslog-e2e -f ops/containers/e2e/Dockerfile .

container-k6: prep-local
	docker build -t itslog-k6 -f ops/containers/k6/Dockerfile .

e2e: container-api container-e2e
	docker compose \
	-f ops/containers/docker-compose-e2e.yaml \
	up \
	--abort-on-container-exit

k6: container-api container-k6
	docker compose \
	-f ops/containers/docker-compose-k6.yaml \
	up \
	--no-attach itslog \
	--abort-on-container-exit
