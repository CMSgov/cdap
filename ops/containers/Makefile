.PHONY: e2e amd arm k6 k6-build kd-arm k6-amd itslog itslog-arm itslog-amd 

e2e:
	docker compose \
	-f docker-compose-e2e.yaml \
	up \
	--abort-on-container-exit

e2e-build:
	docker compose \
	-f docker-compose-e2e.yaml \
	up \
	--build \
	--abort-on-container-exit

amd:
	cd ../../api ; make linux-amd
arm:
	cd ../../api ; make linux-arm

native:
	cd ../../api ; make native

k6:
	docker compose \
	-f docker-compose-k6.yaml \
	up \
	--abort-on-container-exit

k6-build:
	export BUILDX_METADATA_PROVENANCE=false ;\
	docker compose \
	-f docker-compose-k6.yaml \
	up \
	--build \
	--abort-on-container-exit


itslog:
	docker compose \
	-f docker-compose.yaml \
	up

itslog-build:
	docker compose \
	-f docker-compose.yaml \
	up --build

storage:
	docker compose \
	-f docker-compose-s3.yaml \
	up

itslog-arm: arm itslog

itslog-arm-build: arm itslog-build

itslog-amd: amd itslog

itslog-amd-build: amd itslog-build