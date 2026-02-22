### Setting Up the Software Factory with OpenClaw and Antfarm

Based on Ryan Carson's description of the "Code Factory," this setup uses OpenClaw as the base AI agent orchestration layer and Antfarm to define a team of specialized agents for software development tasks like planning, implementing, verifying, testing, reviewing, and creating PRs. The factory enables AI agents to handle the full code lifecycle in a deterministic way.

#### Step 1: Install OpenClaw
OpenClaw is the foundation. Install it globally using npm (requires Node.js >= 22):

```
npm install -g openclaw@latest
```

Run the onboarding wizard to set up the gateway, workspace, channels, and skills:

```
openclaw onboard --install-daemon
```

This installs OpenClaw as a daemon service (launchd on macOS, systemd on Linux) so it runs in the background.

#### Step 2: Configure OpenClaw
OpenClaw uses a JSON config file at `~/.openclaw/openclaw.json`. Here's a minimal example configured for Anthropic's Claude model (recommended for agentic tasks), with Telegram as an example channel (replace with your bot token). Add your API keys for models like Anthropic or OpenAI in the environment or config.

```json
{
  "agent": {
    "model": "anthropic/claude-opus-4-6",
    "defaults": {
      "workspace": "~/.openclaw/workspace",
      "sandbox": {
        "mode": "non-main"
      }
    }
  },
  "channels": {
    "telegram": {
      "botToken": "YOUR_TELEGRAM_BOT_TOKEN",
      "allowFrom": ["*"],
      "groups": {
        "*": {
          "requireMention": true
        }
      }
    }
  },
  "gateway": {
    "port": 18789,
    "bind": "127.0.0.1",
    "tailscale": {
      "mode": "serve"
    },
    "auth": {
      "mode": "password",
      "password": "YOUR_SECURE_PASSWORD"
    }
  }
}
```

- **agent.model**: Set to your preferred LLM (e.g., "openai/gpt-4o" if using OpenAI).
- **channels**: Configure messaging platforms for agent interaction (e.g., WhatsApp, Slack, Discord). Obtain tokens from the respective developer portals.
- **gateway**: Controls the WebSocket server for clients and tools.
- **sandbox**: Enables Docker-based isolation for non-main sessions to enhance security during agent runs.

Add API keys via environment variables (e.g., `ANTHROPIC_API_KEY=your-key`) or in the config under "models".

Run `openclaw doctor` to validate the setup.

Start the gateway:

```
openclaw gateway --verbose
```

#### Step 3: Install Antfarm
Antfarm layers on top of OpenClaw to create the agent team. Install it with this one-liner:

```
curl -fsSL https://raw.githubusercontent.com/snarktank/antfarm/v0.5.1/scripts/install.sh | bash
```

Alternatively, if OpenClaw is running, message your agent: "install github.com/snarktank/antfarm".

List available workflows:

```
antfarm workflow list
```

Install a predefined workflow (e.g., feature-dev for full code development):

```
antfarm workflow install feature-dev
```

#### Step 4: Antfarm Workflow Config Files
Antfarm workflows are defined in YAML files. Predefined ones like `feature-dev` are installed automatically, but you can create custom ones for your software factory. Place custom workflows in `~/.antfarm/workflows/` (or wherever Antfarm installs to; check with `antfarm --help`).

Here's an example YAML for a custom "feature-dev" workflow based on the described structure. It defines agents (e.g., planner, developer) and steps in sequence. Each agent has a persona defined in a Markdown file (e.g., `agents/planner/AGENT.md` with instructions like "You are a senior product planner...").

```yaml
id: feature-dev
name: Feature Development Workflow
agents:
  - id: planner
    name: Planner
    workspace:
      files:
        AGENT.md: agents/planner/AGENT.md  # Persona and instructions
  - id: setup
    name: Setup
    workspace:
      files:
        AGENT.md: agents/setup/AGENT.md
  - id: implement
    name: Implement
    workspace:
      files:
        AGENT.md: agents/implement/AGENT.md
  - id: verify
    name: Verify
    workspace:
      files:
        AGENT.md: agents/verify/AGENT.md
  - id: test
    name: Test
    workspace:
      files:
        AGENT.md: agents/test/AGENT.md
  - id: pr
    name: PR Creator
    workspace:
      files:
        AGENT.md: agents/pr/AGENT.md
  - id: review
    name: Reviewer
    workspace:
      files:
        AGENT.md: agents/review/AGENT.md
steps:
  - id: plan
    agent: planner
    input: |
      Decompose the feature request: {{task}} into user stories.
      Reply with STATUS: done and STORIES: [list of stories]
    expects: "STATUS: done"
  - id: setup_env
    agent: setup
    input: |
      Set up the development environment for story: {{previous_output.story}}.
      Clone repo, install deps, etc.
      Reply with STATUS: done and ENV_READY: true
    expects: "STATUS: done"
  - id: implement_code
    agent: implement
    input: |
      Implement the code for story: {{previous_output.story}}.
      Write files and commit changes.
      Reply with STATUS: done and CHANGES: [summary]
    expects: "STATUS: done"
  - id: verify_impl
    agent: verify
    input: |
      Verify the implementation for story: {{previous_output.story}}.
      Check for errors and completeness.
      Reply with STATUS: done or retry with ISSUES: [list]
    expects: "STATUS: done"
    retry: 3  # Automatic retries
  - id: run_tests
    agent: test
    input: |
      Run unit and E2E tests for the changes.
      Reply with STATUS: done and TEST_RESULTS: passed
    expects: "STATUS: done"
  - id: create_pr
    agent: pr
    input: |
      Create a GitHub PR with the changes.
      Use gh CLI to submit.
      Reply with STATUS: done and PR_URL: [url]
    expects: "STATUS: done"
  - id: review_pr
    agent: review
    input: |
      Review the PR: {{previous_output.pr_url}}.
      Suggest improvements or approve.
      Reply with STATUS: done and REVIEW: approved
    expects: "STATUS: done"
```

- **id/name**: Workflow identifiers.
- **agents**: List of agents with workspaces (directories containing AGENT.md for prompts/personas).
- **steps**: Sequential tasks with input prompts (using {{task}} or {{previous_output}} for chaining), expected output patterns for validation, and optional retries.
- Create supporting AGENT.md files in the specified paths, e.g., for planner:

```
# agents/planner/AGENT.md
You are a senior product planner. Break down features into actionable user stories. Always output in JSON format.
```

To run the workflow:

```
antfarm workflow run feature-dev "Implement user authentication with OAuth"
```

Monitor with:

```
antfarm workflow status "OAuth"
antfarm dashboard  # Starts a web dashboard on port 3333
```

#### Step 5: Integrate with Your Repo
- Ensure the gh CLI is installed for PR creation (`brew install gh` on macOS).
- Set up GitHub credentials in OpenClaw's workspace or environment.
- For Vercel/Supabase/Railway integration (as mentioned in similar setups), add skills to OpenClaw's workspace (`~/.openclaw/workspace/skills/`) with Markdown files describing API interactions, e.g., `skills/vercel/SKILL.md` with prompts for deployment.

This configures a complete AI-driven software factory. Test with small tasks and scale up. If using paid models, monitor usage with `/usage full` in chat.