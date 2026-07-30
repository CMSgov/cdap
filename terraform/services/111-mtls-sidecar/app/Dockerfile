# Build
FROM golang:1.24-alpine AS builder

WORKDIR /build

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/ .

# create cert directory with ownership for distroless nonroot
RUN mkdir -p /etc/certs && chown 65532:65532 /etc/certs && chmod 700 /etc/certs

RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -o /proxy \
    ./cmd/proxy

#Test
FROM golang:1.24-alpine AS tester

WORKDIR /app

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/ .

# coverage output dir
RUN mkdir -p /app/coverage

#RUNTIME
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /proxy /proxy
COPY --from=builder /etc/certs /etc/certs

USER nonroot:nonroot

ENTRYPOINT ["/proxy"]