# claude-code-marketplace

getty104's Claude Code Plugin Marketplace

## Overview

This repository is a plugin marketplace for Claude Code that automates TDD (Test-Driven Development) based development workflows. It provides specialized agents, skills, and hooks to streamline the entire development process, from GitHub Issue implementation to code review responses.

The **marketplace format** enables centralized management of multiple plugins and easy sharing with teams and communities.

## Features

- **TDD Automation**: Automatically executes the test creation → implementation → quality check cycle
- **GitHub Integration**: Automates Issue implementation and review comment responses
- **git worktree Utilization**: Safe working environment isolated from the main branch
- **Layered Architecture Compliance**: Maintains consistent code structure
- **Quality Assurance**: Automatically runs lint, tests, and type checks
- **Library Documentation Access**: Integrated MCP servers for Next.js, shadcn, and other libraries

## Installation

### Prerequisites

- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/installation) installed
- Node.js (if used in your project)
- Docker (if used in your project)
- [GitHub CLI (`gh`)](https://cli.github.com/)

### Adding the Marketplace

Add to your Claude Code settings file (`~/.config/claude/settings.json`):

```json
{
  "plugin_marketplaces": [
    "https://github.com/getty104/claude-code-marketplace"
  ]
}
```

Or add directly via Claude Code command:

```bash
claude marketplace add https://github.com/getty104/claude-code-marketplace
```

### Installing Plugins

After adding the marketplace, included plugins will be automatically available:

```bash
claude plugin install base-tools
```

### MCP Configuration

The `.mcp.json` included in the plugin automatically configures the following MCP servers:
- **chrome-devtools**: Browser automation and DevTools integration
- **context7**: Library documentation retrieval (HTTP-based, no API key required)
- **next-devtools**: Next.js development tools and documentation
- **shadcn**: shadcn/ui component library integration

## Marketplace Composition

This marketplace includes the following plugins:

### base-tools Plugin

An integrated plugin for automating TDD development workflows. Composed of four component types:

1. **Agents** (`agents/`) - Specialized sub-agents
2. **Skills** (`skills/`) - Reusable skill prompts and slash commands
3. **Hooks** (`hooks/hooks.json`) - Event handlers
4. **MCP Servers** (`.mcp.json`) - External tool integration

## Key Features

### Agents

#### general-purpose-assistant
General-purpose agent for diverse tasks requiring broad problem-solving capabilities

**Features**:
- Comprehensive problem analysis and solution
- Adherence to project conventions (TDD, no comments, layered architecture)
- LSP-first code exploration strategy
- Flexible task execution across multiple domains

**Usage Example**:
```
Explain the overall project structure
Provide advice on improving development efficiency
```

### Skills

Skills are reusable prompts that can be invoked to perform specific tasks. Each skill can be invoked using the `/skill-name` syntax (e.g., `/exec-issue 123`).

#### `/exec-issue <issue number>`
Reads GitHub Issue and automates from implementation to PR creation

**Execution Steps**:
1. Create git worktree via `create-git-worktree` skill
2. Read and analyze Issue content via `read-github-issue` skill
3. Implement tasks using `general-purpose-assistant` sub-agent
4. Commit and push via `commit-push` skill
5. Create PR via `create-pr` skill

#### `/create-issue <task description>`
Analyzes task requirements and creates a GitHub Issue with implementation plan

**Execution Steps**:
1. Move to default branch and pull latest changes
2. Analyze task requirements using Explore sub-agent
3. Create GitHub Issue with structured implementation plan
4. Iterate on Issue content based on user feedback

#### `/fix-review-point <branch name>`
Address unresolved review comments on specified branch

**Execution Steps**:
1. Prepare git worktree
2. Retrieve unresolved review comments via `read-unresolved-pr-comments` skill
3. Implement fixes using `general-purpose-assistant` sub-agent
4. Commit, push, and resolve comments
5. Request re-review via `/gemini review` comment

#### `/fix-review-point-loop <branch name>`
Repeatedly address review comments until none remain (checks every 5 minutes)

#### `/check-library`
Retrieves library documentation using appropriate MCP servers

**Features**:
- Next.js: Uses next-devtools MCP
- shadcn/ui: Uses shadcn MCP
- Other libraries: Uses context7 MCP

**Usage Example**:
```
/check-library React Query
```

#### `/create-git-worktree <branch name>`
Automates git worktree creation and environment setup

**Features**:
- Creates worktree in `.git-worktrees/` directory
- Automatically converts `/` to `-` in branch names
- Copies .env files
- Installs dependencies (npm install)
- Reuses existing worktrees

**Usage Example**:
```
/create-git-worktree feature/new-feature
```

#### `/commit-push`
Guides appropriate git commit strategies and pushes code changes

**Features**:
- Squash strategy (default): Amend to existing commits
- New commit: For independent changes
- Interactive rebase: For reorganizing commit history
- Commit message guidelines (type, subject, body, footer)
- Automatic push with `--force-with-lease`

**Usage Example**:
```
/commit-push
```

#### `/read-github-issue <issue number>`
Retrieves GitHub Issue content and creates an implementation plan

**Features**:
- Fetches Issue title, body, comments, labels, and assignments
- Downloads images from Issues using gh-asset
- Creates detailed implementation plan from Issue content

**Usage Example**:
```
/read-github-issue 123
```

#### `/create-pr`
Creates GitHub Pull Request with proper template

**Features**:
- Uses `.github/PULL_REQUEST_TEMPLATE.md` for description
- Removes commented sections from template
- Includes `Closes #<issue number>` in description
- Auto-assigns the current user

**Usage Example**:
```
/create-pr
```

#### `/read-unresolved-pr-comments`
Retrieves unresolved PR comments and creates a fix plan

**Features**:
- Fetches unresolved Review threads via GitHub GraphQL API
- Analyzes comment content and identifies required fixes
- Creates structured fix plan

**Usage Example**:
```
/read-unresolved-pr-comments
```

#### `/resolve-pr-comments`
Batch resolves PR Review threads via GitHub GraphQL API

**Features**:
- Automatically resolves all unresolved Review threads
- Uses resolveReviewThread mutation

**Usage Example**:
```
/resolve-pr-comments
```

## Development Guidelines

### TDD (Test-Driven Development)

1. Create tests (in same directory as test target file)
2. Run tests (confirm failure)
3. Implementation
4. Run tests (confirm success)
5. Refactoring

### Code Quality Standards

- All tests must pass
- Zero errors from `npm run lint`
- TypeScript type safety ensured
- No comments (code should be self-explanatory)
- Minimal file changes

### Layered Architecture

- **Model Layer**: Business logic
- **Infrastructure Layer**: Database, external APIs
- **Application Layer**: Use cases
- **Presentation Layer**: UI/API responses

## Directory Structure

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json                    # Marketplace manifest
│
├── base-tools/                             # base-tools plugin
│   ├── .claude-plugin/
│   │   └── plugin.json                     # Plugin manifest (auto-generated)
│   ├── .mcp.json                           # MCP server configuration
│   ├── agents/                             # Agent definitions
│   │   └── general-purpose-assistant.md    # General-purpose agent
│   ├── skills/                             # Skill definitions
│   │   ├── check-library/                  # Library documentation skill
│   │   │   ├── SKILL.md
│   │   │   └── examples.md
│   │   ├── commit-push/                    # Commit and push skill
│   │   │   ├── SKILL.md
│   │   │   ├── examples.md
│   │   │   └── reference.md
│   │   ├── create-git-worktree/            # Worktree creation skill
│   │   │   ├── SKILL.md
│   │   │   └── scripts/
│   │   │       └── create-worktree.sh
│   │   ├── create-issue/                   # Issue creation skill
│   │   │   └── SKILL.md
│   │   ├── create-pr/                      # PR creation skill
│   │   │   └── SKILL.md
│   │   ├── exec-issue/                     # Issue execution skill
│   │   │   └── SKILL.md
│   │   ├── fix-review-point/               # Review fix skill
│   │   │   └── SKILL.md
│   │   ├── fix-review-point-loop/          # Repeated review fix skill
│   │   │   └── SKILL.md
│   │   ├── read-github-issue/              # GitHub Issue retrieval skill
│   │   │   └── SKILL.md
│   │   ├── read-unresolved-pr-comments/    # PR comment retrieval skill
│   │   │   ├── SKILL.md
│   │   │   └── scripts/
│   │   │       └── read-unresolved-pr-comments.sh
│   │   └── resolve-pr-comments/            # PR comment resolution skill
│   │       ├── SKILL.md
│   │       └── scripts/
│   │           └── resolve-pr-comments.sh
│   ├── scripts/                            # Utility scripts
│   │   └── remove-merged-worktrees.sh      # Cleanup merged worktrees
│   └── hooks/                              # Hook definitions
│       └── hooks.json                      # Event handlers
│
├── CLAUDE.md                               # Claude Code guide
└── README.md                               # This file
```

### Marketplace Manifest

`.claude-plugin/marketplace.json` defines marketplace metadata:

```json
{
  "name": "getty104",
  "metadata": {
    "description": "getty104's marketplace",
    "version": "0.0.1"
  },
  "owner": {
    "name": "getty104"
  },
  "plugins": [
    {
      "name": "base-tools",
      "source": "./base-tools",
      "description": "This is a getty104's base tool set"
    }
  ]
}
```

## Development and Customization

### Adding Agents

Create `.md` files in `base-tools/agents/`. Define `name`, `description`, `model`, and `color` in frontmatter:

```markdown
---
name: custom-agent
description: Description of when this agent should be used (Claude Code uses for auto-judgment)
model: sonnet
color: cyan
---

Write agent prompt content here.
This prompt will be passed to the sub-agent.
```

**Best Practices**:
- Make `description` clear and specific (Claude Code automatically invokes at appropriate times)
- Create agents with specialized roles
- Specify communication requirements (e.g., Japanese language)

### Adding Skills

Create a directory in `base-tools/skills/` with a `SKILL.md` file:

```markdown
---
name: skill-name
description: Description of what this skill does and when to use it
model: haiku
---

# Skill Title

## Instructions

Detailed instructions for executing the skill...
```

Skills can include the following structure:
```
skills/
└── my-skill/
    ├── SKILL.md              # Main skill definition (required)
    ├── scripts/              # Shell scripts for automation (optional)
    │   └── my-script.sh
    ├── examples.md           # Usage examples (optional)
    └── reference.md          # Additional reference material (optional)
```

**Frontmatter Fields**:
- `name`: Skill name (defaults to directory name if omitted)
- `description`: Skill description (used by Claude for auto-invocation judgment)
- `model`: Model to use (`haiku`, `sonnet`, `opus`)
- `disable-model-invocation`: Set to `true` to disable automatic Claude invocation (user-only)
- `user-invocable`: Set to `false` to hide from `/` menu (Claude-only)
- `argument-hint`: Hint displayed during autocomplete (e.g., `"[issue-number]"`)
- `context`: Set to `fork` to run as sub-agent
- `agent`: Agent type to use when `context: fork` is set (e.g., `general-purpose`)

### Configuring Hooks

Configure event handlers in `base-tools/hooks/hooks.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "your-command-here"
          }
        ]
      }
    ]
  }
}
```

Available events: `PreToolUse`, `PostToolUse`, `Stop`, etc.

### Adding MCP Servers

Add new MCP servers to `.mcp.json`:

```json
{
  "mcpServers": {
    "server-name": {
      "command": "command",
      "args": ["arg1", "arg2"]
    }
  }
}
```

For HTTP-based MCP servers:

```json
{
  "mcpServers": {
    "server-name": {
      "type": "http",
      "url": "https://example.com/mcp"
    }
  }
}
```

For Python-based MCP servers (using uv):

```json
{
  "mcpServers": {
    "server-name": {
      "command": "uvx",
      "args": ["--from", "git+https://github.com/org/repo", "package", "start-mcp-server"]
    }
  }
}
```

## Plugin Validation

Always validate plugins before distribution:

```bash
claude plugin validate base-tools/
```

Run local tests:

```bash
claude plugin install ./base-tools
```

## Sharing the Marketplace

To share this marketplace with teams or communities:

### Public Sharing

Publish repository on GitHub and share the URL:

```bash
https://github.com/getty104/claude-code-marketplace
```

### Private Sharing

Grant team members access to the repository, then use the same URL.

### Fork and Customize

Fork this marketplace to add your own plugins:

1. Fork the repository
2. Update `owner` in `.claude-plugin/marketplace.json`
3. Add new plugins or modify existing ones
4. Validate and commit

## Troubleshooting

### Plugin Not Recognized

Check with:

```bash
claude plugin list
```

Verify that the marketplace has been added correctly.

### MCP Server Won't Start

Ensure the required tools are installed:
- `npx` for Node.js-based servers
- `uvx` for Python-based servers (requires uv)

### Command Won't Execute

Verify that skill file names are correct. Directory names become skill names as-is.

## Resources

- [Claude Code Official Documentation](https://docs.claude.com/en/docs/claude-code)
- [Plugin Marketplace Guide](https://anthropic.mintlify.app/en/docs/claude-code/plugin-marketplaces)
- [Plugin Reference](https://anthropic.mintlify.app/en/docs/claude-code/plugins-reference)

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss the proposed changes.

## License

MIT

## Author

getty104

## Support

For questions or issues, please report them in [GitHub Issues](https://github.com/getty104/claude-code-marketplace/issues).
