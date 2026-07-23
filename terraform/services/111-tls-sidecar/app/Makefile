.PHONY: build run down test clean

build:
	docker compose -f docker-compose.yml build

run:
	docker compose -f docker-compose.yml up

down:
	docker compose -f docker-compose.yml down

test:
	curl -s http://localhost:8443/

clean:
	docker compose -f docker-compose.yml down --rmi all
