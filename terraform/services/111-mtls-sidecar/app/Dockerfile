# ---- Build Stage ----
FROM golang:1.26.5-alpine3.24 AS builder

WORKDIR /build

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/ .

RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -o /proxy \
    ./cmd/proxy

# ---- Runtime Stage ----
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /proxy /proxy

USER nonroot:nonroot

ENTRYPOINT ["/proxy"]
