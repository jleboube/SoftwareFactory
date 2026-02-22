#!/usr/bin/env bash
set -euo pipefail

# SoftwareFactory Container Entrypoint
# Validates environment, configures tools, starts OpenClaw gateway

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [entrypoint] $*"
}

warn() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [entrypoint] WARN: $*"
}

error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [entrypoint] ERROR: $*" >&2
}

# -- Validate required environment variables ---------------------
if [ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  error "OPENCLAW_GATEWAY_TOKEN is not set."
  error "Generate one with: openssl rand -hex 32"
  exit 1
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${OPENAI_API_KEY:-}" ]; then
  warn "No AI provider API key set (ANTHROPIC_API_KEY or OPENAI_API_KEY)."
  warn "Agents will not function without an API key."
fi

# -- Ensure directory structure ----------------------------------
mkdir -p "$HOME/.openclaw/workspace" \
         "$HOME/.antfarm" \
         "/data/antfarm-db" 2>/dev/null || true

# -- Configure git -----------------------------------------------
if [ -n "${GIT_USER_NAME:-}" ]; then
  git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
fi
git config --global --add safe.directory '*'
git config --global init.defaultBranch main

# -- GitHub CLI authentication -----------------------------------
if [ -n "${GH_TOKEN:-}" ]; then
  log "GitHub CLI authenticated via GH_TOKEN."
else
  warn "GH_TOKEN not set. PR creation and review steps will fail."
fi

# -- Install Antfarm workflows -----------------------------------
if command -v antfarm >/dev/null 2>&1; then
  log "Antfarm CLI found. Installing workflows..."
  antfarm install 2>/dev/null || warn "Antfarm install returned non-zero (may be OK on first run)."
  log "Available workflows:"
  antfarm workflow list 2>/dev/null || true
else
  warn "Antfarm CLI not found in PATH."
fi

# -- Dispatch command --------------------------------------------
case "${1:-gateway}" in
  gateway)
    log "Starting OpenClaw gateway on port 18789..."
    exec openclaw gateway --verbose
    ;;
  shell)
    log "Starting interactive shell..."
    exec /bin/bash
    ;;
  antfarm)
    shift
    log "Running antfarm: $*"
    exec antfarm "$@"
    ;;
  openclaw)
    shift
    log "Running openclaw: $*"
    exec openclaw "$@"
    ;;
  doctor)
    log "Running OpenClaw diagnostics..."
    exec openclaw doctor
    ;;
  *)
    log "Running: $*"
    exec "$@"
    ;;
esac
