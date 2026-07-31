# Build
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder

WORKDIR /build

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/ .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build \
    -ldflags="-w -s" \
    -o /proxy \
    ./cmd/proxy

# Test
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS tester

WORKDIR /app

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/ .

RUN mkdir -p /app/coverage

# Runtime
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /proxy /proxy

USER nonroot:nonroot

ENTRYPOINT ["/proxy"]
