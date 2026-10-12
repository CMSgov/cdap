# The build stage
FROM golang:1.26.0-trixie AS builder
RUN apt-get update && apt-get install -y make unzip awscli
ENV GOPROXY=direct

WORKDIR /app
COPY api /app/api
COPY ops/containers/itslog/scripts/internal/entrypoint.bash . 

WORKDIR /app/api
# 2. BuildKit Cache Mounts: Cache downloaded packages 
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o its-log . 

# The run stage
FROM golang:1.26.0-trixie AS prod
RUN apt update ; apt install -y jq awscli

WORKDIR /app
COPY --from=builder /app/api/its-log .
COPY --from=builder /app/entrypoint.bash .
# We want to mount -v ${PWD}/data:/data for SQLite writing.
RUN chmod 755 ./its-log
CMD ["./entrypoint.bash"]