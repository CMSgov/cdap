# The build stage
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder
ENV GOPROXY=direct

RUN dnf update -y && \
    dnf install -y \
        ca-certificates \
        gcc-c++ \
        golang \
        libstdc++-devel \
        && \
    dnf clean all

WORKDIR /app
COPY api /app/api
COPY ops /app/ops

WORKDIR /app/api
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o its-log

# The run stage
FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal as prod
# COPY --from=builder /usr/bin/jq /usr/bin/jq
RUN dnf install -y jq

WORKDIR /app
COPY --from=builder /app/api/its-log .
COPY --from=builder /app/ops/containers/itslog/scripts/internal/entrypoint.bash .
RUN chmod 755 ./its-log
CMD ["./entrypoint.bash"]
