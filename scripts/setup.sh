#!/usr/bin/env bash
set -euo pipefail

# SoftwareFactory First-Time Setup Wizard
# Configures environment, builds image, and starts services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[setup]${NC} $*"; }
err()  { echo -e "${RED}[setup]${NC} ERROR: $*" >&2; }

banner() {
  echo ""
  echo -e "${BLUE}+------------------------------------------+${NC}"
  echo -e "${BLUE}|     Software Factory Setup Wizard         |${NC}"
  echo -e "${BLUE}|     OpenClaw + Antfarm                    |${NC}"
  echo -e "${BLUE}+------------------------------------------+${NC}"
  echo ""
}

check_prerequisites() {
  log "Checking prerequisites..."
  local missing=0

  if ! command -v docker >/dev/null 2>&1; then
    err "Docker is not installed. Install from https://docs.docker.com/get-docker/"
    missing=1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    err "Docker Compose is not available."
    missing=1
  fi

  if [ $missing -ne 0 ]; then
    err "Missing prerequisites. Install them and re-run."
    exit 1
  fi

  log "Prerequisites OK."
}

generate_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || \
    head -c 32 /dev/urandom | xxd -p
  fi
}

create_env() {
  if [ -f "$ENV_FILE" ]; then
    warn ".env file already exists."
    read -rp "Overwrite? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
      log "Keeping existing .env."
      return
    fi
  fi

  log "Generating gateway token..."
  local token
  token=$(generate_token)

  echo ""
  log "Configure your API keys (press Enter to skip any):"
  echo ""

  read -rp "  Anthropic API key: " anthropic_key
  read -rp "  OpenAI API key: " openai_key

  if [ -z "$anthropic_key" ] && [ -z "$openai_key" ]; then
    warn "No AI provider key set. Add one to .env before running workflows."
  fi

  read -rp "  GitHub personal access token (for PR workflows): " gh_token
  read -rp "  Git user name [SoftwareFactory Bot]: " git_name
  git_name="${git_name:-SoftwareFactory Bot}"
  read -rp "  Git email [bot@localhost]: " git_email
  git_email="${git_email:-bot@localhost}"
  read -rp "  External port [47391]: " ext_port
  ext_port="${ext_port:-47391}"

  cat > "$ENV_FILE" <<EOF
# SoftwareFactory Environment - Generated $(date -u +"%Y-%m-%dT%H:%M:%SZ")
OPENCLAW_GATEWAY_TOKEN=${token}
ANTHROPIC_API_KEY=${anthropic_key}
OPENAI_API_KEY=${openai_key}
GH_TOKEN=${gh_token}
GIT_USER_NAME=${git_name}
GIT_USER_EMAIL=${git_email}
SF_EXTERNAL_PORT=${ext_port}
EOF

  chmod 600 "$ENV_FILE"
  log ".env created with restrictive permissions (600)."
  echo ""
  log "Gateway token: ${token}"
  warn "Save this token - you need it to connect clients to the gateway."
}

create_dirs() {
  log "Creating data directories..."
  mkdir -p "$PROJECT_DIR/data/openclaw" \
           "$PROJECT_DIR/data/workspace" \
           "$PROJECT_DIR/data/antfarm-db" \
           "$PROJECT_DIR/nginx/ssl"
  log "Done."
}

build_and_start() {
  log "Building Docker image (this may take several minutes)..."
  docker compose -f "$PROJECT_DIR/docker-compose.yml" build

  log "Starting services..."
  docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d

  log "Waiting for services to become healthy..."
  local retries=30
  while [ $retries -gt 0 ]; do
    if docker compose -f "$PROJECT_DIR/docker-compose.yml" ps --format json 2>/dev/null | grep -q '"healthy"'; then
      break
    fi
    sleep 3
    retries=$((retries - 1))
  done

  if [ $retries -eq 0 ]; then
    warn "Services may still be starting. Check: docker compose ps"
  else
    log "Services are running."
  fi
}

print_summary() {
  local port
  port=$(grep SF_EXTERNAL_PORT "$ENV_FILE" 2>/dev/null | cut -d= -f2)
  port="${port:-47391}"

  echo ""
  echo -e "${GREEN}===========================================${NC}"
  echo -e "${GREEN}  Software Factory is ready!${NC}"
  echo -e "${GREEN}===========================================${NC}"
  echo ""
  echo "  Gateway:    http://localhost:${port}"
  echo "  Health:     http://localhost:${port}/health"
  echo ""
  echo "  Commands:"
  echo "    docker compose logs -f                                # View logs"
  echo "    docker compose exec sf-openclaw antfarm workflow list # List workflows"
  echo "    docker compose exec sf-openclaw antfarm workflow run sf-feature-dev \"Your task here\""
  echo "    docker compose down                                   # Stop"
  echo ""
}

main() {
  banner
  check_prerequisites
  create_env
  create_dirs
  build_and_start
  print_summary
}

main "$@"
