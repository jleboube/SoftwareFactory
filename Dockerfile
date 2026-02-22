# ============================================================
# SoftwareFactory Dockerfile
# Multi-stage build: OpenClaw + Antfarm + GitHub CLI
# ============================================================

# Stage 1: Build Antfarm from source
# ------------------------------------------------------------
FROM node:22-bookworm-slim AS antfarm-builder

ARG ANTFARM_VERSION=v0.5.1

RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone --depth 1 --branch "${ANTFARM_VERSION}" \
      https://github.com/snarktank/antfarm.git . && \
    npm ci --no-fund --no-audit && \
    npm run build && \
    npm prune --production

# Stage 2: Production image
# ------------------------------------------------------------
FROM node:22-bookworm-slim AS production

LABEL maintainer="SoftwareFactory"
LABEL description="OpenClaw + Antfarm AI Software Factory"
LABEL version="1.0.0"

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      curl \
      ca-certificates \
      sqlite3 \
      tini \
      gnupg && \
    # Install GitHub CLI from official apt repo
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends gh && \
    # Cleanup
    apt-get purge -y gnupg && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest && \
    npm cache clean --force

# Set up non-root user directories
RUN mkdir -p /home/node/.openclaw/workspace/antfarm \
             /home/node/.antfarm \
             /data/antfarm-db && \
    chown -R node:node /home/node /data

# Copy Antfarm build from stage 1
COPY --from=antfarm-builder --chown=node:node /build /home/node/.openclaw/workspace/antfarm

# Link Antfarm CLI globally
WORKDIR /home/node/.openclaw/workspace/antfarm
RUN npm link 2>/dev/null || true

# Copy entrypoint and healthcheck scripts
COPY --chown=node:node scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=node:node scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Copy OpenClaw configuration template
COPY --chown=node:node config/openclaw.json /home/node/.openclaw/openclaw.json

# Copy workflow definitions
COPY --chown=node:node workflows/ /home/node/.openclaw/workspace/antfarm/workflows/

# Security: run as non-root
USER node
WORKDIR /home/node

ENV NODE_ENV=production
ENV HOME=/home/node

# OpenClaw gateway port (internal only - nginx proxies externally)
EXPOSE 18789

# Use tini as init system for proper signal handling
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["gateway"]
