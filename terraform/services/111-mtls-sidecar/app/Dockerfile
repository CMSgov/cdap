# Build
FROM golang:1.24-alpine AS builder

WORKDIR /build

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/ .

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

ENTRYPOINT ["sh", "-c"]

#RUNTIME
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /proxy /proxy

USER nonroot:nonroot

ENTRYPOINT ["/proxy"]