# Build
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

WORKDIR /build

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/ .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build \
    -ldflags="-w -s" \
    -o /proxy \
    ./cmd/proxy

RUN mkdir -p /etc/certs \
    && touch /etc/certs/.keep \
    && chown -R 65532:65532 /etc/certs \
    && chmod 700 /etc/certs

# Test
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS tester

WORKDIR /app

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/ .

RUN mkdir -p /app/coverage

# Runtime — no --platform needed, TARGETPLATFORM is the default
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /proxy /proxy
COPY --from=builder --chown=65532:65532 /etc/certs /etc/certs

USER nonroot:nonroot

ENTRYPOINT ["/proxy"]
