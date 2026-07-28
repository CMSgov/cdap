# ---- Build Stage ----
FROM golang:1.22-alpine AS builder

WORKDIR /build

COPY src/go.mod ./
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
