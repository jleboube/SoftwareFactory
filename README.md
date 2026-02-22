# Software Factory

AI-powered software development factory using [OpenClaw](https://openclaw.ai) and [Antfarm](https://www.antfarm.cool). Seven specialized AI agents handle the full development lifecycle: planning, environment setup, implementation, verification, testing, PR creation, and code review.

## Architecture

```
                    Port 47391
                       |
                  +----v----+
                  |  Nginx  |  Security headers, rate limiting,
                  | (proxy) |  WebSocket proxy
                  +----+----+
                       |
              internal network (isolated)
                       |
                  +----v----+
                  | OpenClaw |  AI agent gateway
                  | Antfarm  |  Multi-agent orchestration
                  |  gh CLI  |  GitHub integration
                  +----------+
```

**Agent Pipeline:**

```
Plan --> Setup --> Implement --> Verify --> Test --> PR --> Review
                      ^           |
                      +--(retry)--+
```

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Compose
- An AI provider API key (Anthropic recommended)
- GitHub personal access token (for PR workflows)

### Setup

```bash
# Run the interactive setup wizard
./scripts/setup.sh
```

Or manually:

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your API keys

# 2. Generate a gateway token
echo "OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)" >> .env

# 3. Build and start
docker compose up -d

# 4. Verify
curl http://localhost:47391/health
```

### Run a Workflow

```bash
# List available workflows
docker compose exec sf-openclaw antfarm workflow list

# Run feature development
docker compose exec sf-openclaw antfarm workflow run sf-feature-dev \
  "Implement user authentication with OAuth for the /api/auth endpoints"

# Check workflow status
docker compose exec sf-openclaw antfarm workflow status
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENCLAW_GATEWAY_TOKEN` | Yes | Gateway authentication token |
| `ANTHROPIC_API_KEY` | Yes* | Anthropic Claude API key |
| `OPENAI_API_KEY` | Yes* | OpenAI API key |
| `GH_TOKEN` | For PRs | GitHub personal access token |
| `GIT_USER_NAME` | No | Git commit author name |
| `GIT_USER_EMAIL` | No | Git commit author email |
| `SF_EXTERNAL_PORT` | No | External port (default: 47391) |

*At least one AI provider key is required.

### Changing the AI Model

Edit `config/openclaw.json`:

```json
{
  "agent": {
    "model": "anthropic/claude-opus-4-6"
  }
}
```

Supported models: `anthropic/claude-opus-4-6`, `anthropic/claude-sonnet-4-6`, `openai/gpt-4o`, and others.

### Adding Messaging Channels

```bash
# Telegram
docker compose exec sf-openclaw openclaw channels add --channel telegram --token <bot-token>

# Slack
docker compose exec sf-openclaw openclaw channels add --channel slack --token <bot-token>
```

### TLS/HTTPS

1. Place certificates in `nginx/ssl/`:
   - `fullchain.pem` - certificate chain
   - `privkey.pem` - private key
2. Uncomment the TLS server block in `nginx/conf.d/default.conf`
3. Uncomment `SF_EXTERNAL_TLS_PORT` in `.env`
4. Restart: `docker compose restart sf-nginx`

## Agent Team

| Agent | Role | Description |
|-------|------|-------------|
| **Planner** | Analysis | Decomposes features into ordered user stories |
| **Setup** | Coding | Prepares environment, creates branches, establishes baseline |
| **Implement** | Coding | Writes code and tests, one story per session |
| **Verify** | Verification | Quality gate checking acceptance criteria |
| **Test** | Testing | Integration and E2E testing |
| **PR Creator** | Coding | Creates GitHub pull requests with documentation |
| **Reviewer** | Analysis | Reviews PRs for quality, security, conventions |

## Security

- **Network isolation**: OpenClaw is on an internal-only Docker network; only Nginx faces the outside
- **Reverse proxy**: All traffic goes through Nginx with security headers
- **Rate limiting**: API (10r/s), WebSocket (2r/s), auth (3r/m) per IP
- **Security headers**: X-Frame-Options, CSP, X-Content-Type-Options, Permissions-Policy
- **Non-root containers**: Both services run as non-root users
- **No-new-privileges**: Containers cannot escalate privileges
- **Token auth**: Gateway requires authentication token
- **Resource limits**: Memory and CPU limits on all containers
- **Read-only Nginx**: Nginx filesystem is read-only with tmpfs
- **TLS-ready**: Configuration prepared for HTTPS enablement

## Operations

```bash
# View logs
docker compose logs -f

# OpenClaw logs only
docker compose logs -f sf-openclaw

# Stop services
docker compose down

# Rebuild after config changes
docker compose up -d --build

# OpenClaw diagnostics
docker compose exec sf-openclaw openclaw doctor

# Interactive shell
docker compose exec sf-openclaw bash
```

## Customization

### Custom Workflows

Create new workflows in `workflows/` following the Antfarm YAML format. Each workflow needs:
- `workflow.yml` - step definitions
- `agents/<name>/AGENTS.md` - behavioral instructions
- `agents/<name>/SOUL.md` - personality
- `agents/<name>/IDENTITY.md` - name and role

### Custom Agent Personas

Edit the files in `workflows/feature-dev/agents/<agent>/` to customize agent behavior for your team's needs.

## Troubleshooting

**Services not starting:**
```bash
docker compose ps        # Check status
docker compose logs      # Check errors
```

**Gateway not responding:**
```bash
docker compose exec sf-openclaw openclaw doctor
```

**Antfarm workflows not found:**
```bash
docker compose exec sf-openclaw antfarm install
docker compose exec sf-openclaw antfarm workflow list
```

## License

Proprietary - Software Factory Template
