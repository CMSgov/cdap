.PHONY: amd native

native:
	cd api ; make native

e2e:
	cd api ; make e2e

k6-build:
	cd ops/containers ; make k6-build

storage:
	cd ops/containers ; make storage

itslog-arm:
	cd ops/containers ; make itslog-arm

itslog-arm-build:
	cd ops/containers ; make itslog-arm-build

itslog-amd:
	cmd ops/containers ; make itslog-amd

generate:
	cd api ; make generate

test:
	cd api ; make test