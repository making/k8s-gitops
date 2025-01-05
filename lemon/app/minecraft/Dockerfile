# ---------------------------------------------------------------------------
# Dockerfile: backup-kubectl-s3client (for Kubernetes v1.31.1)
#   - Based on Alpine Linux
#   - Installs kubectl v1.31.1
#   - Installs MinIO client (mc)
#   - Includes basic utilities: bash, tar, gzip
# ---------------------------------------------------------------------------

FROM alpine:3.18

# Set the kubectl version (1.31.1)
ARG KUBECTL_VERSION=v1.31.1

# Install packages needed for downloading, verifying, and general operations
RUN apk add --update --no-cache \
    ca-certificates \
    curl \
    bash \
    tar \
    gzip

# Install kubectl (v1.31.1)
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/arm64/kubectl" \
    && install -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Install MinIO client (mc) - set MC_VERSION if you need a specific release
ARG MC_VERSION=latest
RUN curl -LO "https://dl.min.io/client/mc/release/linux-arm64/mc" \
    && install -m 0755 mc /usr/local/bin/mc \
    && rm mc

# Optionally set an entrypoint
# ENTRYPOINT ["/bin/bash"]

# ---------------------------------------------------------------------------
# Usage:
#   1. Build the image:
#      docker build -t ghcr.io/making/backup-kubectl-s3client .
#
#   2. Run a container for testing:
#      docker run --rm -it ghcr.io/making/backup-kubectl-s3client sh
#
#   3. Check commands inside the container:
#      kubectl version --client
#      mc --help
#
#   4. (Optional) Push to your registry:
#      docker push your-registry/ghcr.io/making/backup-kubectl-s3client
# ---------------------------------------------------------------------------
