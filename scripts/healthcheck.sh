#!/usr/bin/env bash
set -euo pipefail

# SoftwareFactory Health Check
# Verifies gateway responsiveness and CLI tool availability

GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

# Check 1: OpenClaw gateway is listening
if ! curl -sf --max-time 5 "http://127.0.0.1:${GATEWAY_PORT}/" >/dev/null 2>&1; then
  echo "UNHEALTHY: OpenClaw gateway not responding on port ${GATEWAY_PORT}"
  exit 1
fi

# Check 2: Antfarm CLI is accessible
if ! command -v antfarm >/dev/null 2>&1; then
  echo "UNHEALTHY: Antfarm CLI not found"
  exit 1
fi

# Check 3: gh CLI is accessible
if ! command -v gh >/dev/null 2>&1; then
  echo "UNHEALTHY: GitHub CLI (gh) not found"
  exit 1
fi

echo "HEALTHY"
exit 0
