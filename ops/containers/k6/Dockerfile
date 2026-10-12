FROM grafana/k6:latest AS k6_source

# Step 2: Use your preferred base image (e.g., Node, Alpine, or Ubuntu)
FROM alpine:latest

# Install any required dependencies your environment needs
RUN apk add --no-cache ca-certificates

# Copy the k6 binary from the official image into your path
COPY --from=k6_source /usr/bin/k6 /usr/bin/k6

COPY ops/containers/k6/scripts scripts 

# CMD [ "k6", "run", "10k.js" ]