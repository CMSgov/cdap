# The build stage
FROM public.ecr.aws/amazonlinux/amazonlinux:2023.12.20261112.0-minimal AS builder
ENV GOPROXY=direct

RUN dnf update -y && \
    dnf install -y \
        ca-certificates \
        gcc-c++ \
        git \
        gzip \
        tar

# Ordering will matter for build performance
# on repeated builds. This is mostly a local consideration,
# as we're not at the point of knowing how we might cache in the 
# cloud runners.

# Set the desired Go version
ENV GOLANG_VERSION=1.27.4

RUN curl -fsSL "https://go.dev/dl/go${GOLANG_VERSION}.linux-arm64.tar.gz" -o golang.tar.gz && \
    tar -C /usr/local -xzf golang.tar.gz && \
    rm golang.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

WORKDIR /app/api
COPY src/api/go.mod .
COPY src/api/go.sum .
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY src/api /app/api
COPY src/ops /app/ops

WORKDIR /app/api


RUN --mount=type=cache,target=/go/pkg/mod \
--mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=1 go build -o its-log
# RUN go build -o its-log

# The run stage
FROM public.ecr.aws/amazonlinux/amazonlinux:2023.12.20261112.0-minimal as prod
RUN dnf install -y jq

WORKDIR /app
COPY --from=builder /app/api/its-log .
COPY --from=builder /app/ops/containers/itslog/scripts/internal/entrypoint.bash .
ENV PATH="/usr/local/go/bin:${PATH}"

RUN chmod 755 ./its-log
CMD ["/app/entrypoint.bash"]