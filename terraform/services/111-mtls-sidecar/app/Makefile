COMPOSE_FILE = docker-compose.yml

.PHONY: build run down test test-unit clean certs

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

clean:
	docker compose -f $(COMPOSE_FILE) down --rmi all
