# AutoVault Test Environment
# Multi-stage build for testing on different OS versions

FROM ubuntu:22.04 AS base

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV CI=true

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash \
    jq \
    python3 \
    rsync \
    git \
    curl \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Create test user
RUN useradd -m -s /bin/bash testuser
WORKDIR /home/testuser/autovault

# Copy project files
COPY --chown=testuser:testuser . .

# Make scripts executable
RUN chmod +x cust-run-config.sh bash/*.sh tests/*.sh

# Switch to test user
USER testuser

# Run tests by default
CMD ["./tests/run-tests.sh"]

# ============================================
# Alternative: Alpine-based lightweight image
# ============================================
FROM alpine:latest AS alpine

ENV CI=true

RUN apk add --no-cache \
    bash \
    jq \
    python3 \
    rsync \
    git \
    curl \
    zip

RUN adduser -D -s /bin/bash testuser
WORKDIR /home/testuser/autovault

COPY --chown=testuser:testuser . .
RUN chmod +x cust-run-config.sh bash/*.sh tests/*.sh

USER testuser
CMD ["./tests/run-tests.sh"]

# ============================================
# Development environment with all tools
# ============================================
FROM ubuntu:22.04 AS dev

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bash \
    jq \
    python3 \
    rsync \
    git \
    curl \
    zip \
    shellcheck \
    vim \
    nano \
    less \
    tree \
    && rm -rf /var/lib/apt/lists/*

# Install age for encryption testing
RUN curl -sL https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz | \
    tar xzf - -C /usr/local/bin --strip-components=1 age/age age/age-keygen

RUN useradd -m -s /bin/bash developer
WORKDIR /home/developer/autovault

COPY --chown=developer:developer . .
RUN chmod +x cust-run-config.sh bash/*.sh tests/*.sh

USER developer
CMD ["/bin/bash"]
