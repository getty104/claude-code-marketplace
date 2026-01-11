# claude-code-marketplace

getty104's Claude Code Plugin Marketplace

## Overview

This repository is a plugin marketplace for Claude Code that automates TDD (Test-Driven Development) based development workflows. It provides specialized agents, custom commands, and skills to streamline the entire development process, from GitHub Issue implementation to code review responses.

The **marketplace format** enables centralized management of multiple plugins and easy sharing with teams and communities.

## Features

- **TDD Automation**: Automatically executes the test creation → implementation → quality check cycle
- **GitHub Integration**: Automates Issue implementation and review comment responses
- **git worktree Utilization**: Safe working environment isolated from the main branch
- **Layered Architecture Compliance**: Maintains consistent code structure
- **Quality Assurance**: Automatically runs lint, tests, and type checks
- **Library Documentation Access**: Integrated MCP servers for Next.js, shadcn, and other libraries
- **Semantic Code Analysis**: Serena MCP integration for symbol-level code operations

## Installation

### Prerequisites

- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/installation) installed
- Node.js (if used in your project)
- Docker (if used in your project)
- [GitHub CLI (`gh`)](https://cli.github.com/)
- Python [uv](https://docs.astral.sh/uv/) (for Serena MCP)

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
claude plugin install getty104
```

### MCP Configuration

The `.mcp.json` included in the plugin automatically configures the following MCP servers:
- **chrome-devtools**: Browser automation and DevTools integration
- **context7**: Library documentation retrieval (HTTP-based, no API key required)
- **next-devtools**: Next.js development tools and documentation
- **shadcn**: shadcn/ui component library integration
- **serena**: Semantic code analysis with symbol-level operations (Python/uv required)

## Marketplace Composition

This marketplace includes the following plugins:

### getty104 Plugin

An integrated plugin for automating TDD development workflows. Composed of five component types:

1. **Agents** (`agents/`) - Specialized sub-agents
2. **Commands** (`commands/`) - Custom slash commands
3. **Skills** (`skills/`) - Reusable skill prompts
4. **Hooks** (`hooks/hooks.json`) - Event handlers
5. **MCP Servers** (`.mcp.json`) - External tool integration

## Key Features

### Agents

#### github-issue-implementer
Specialized agent for implementing GitHub Issues and creating PRs

**Features**:
- Analysis of Issue content and implementation planning
- Implementation following TDD cycle
- Code quality checks (lint, tests)
- Automatic PR creation

**Usage Example**:
```
Implement this Issue #123 and create a PR
```

#### review-comment-implementer
Agent specialized in implementing review comments

**Features**:
- Retrieval of unresolved review comments
- TDD approach for fixes
- Resolving review comments
- Automation of re-review requests

**Usage Example**:
```
Check PR review comments and fix the pointed out issues
```

#### pr-review-planner
Agent specialized in analyzing PR review comments and creating fix plans

**Features**:
- Retrieval and analysis of unresolved review comments
- Classification by severity (Critical/Important/Suggestion/Question)
- Structured fix plan creation with priorities
- Impact assessment for each fix

**Usage Example**:
```
Analyze PR review comments and create a fix plan
```

#### task-requirement-analyzer
Agent specialized in analyzing task requirements and creating implementation plans

**Features**:
- Deep analysis of task requirements (explicit and implicit)
- TDD-based phased implementation planning
- Risk and concern identification

**Usage Example**:
```
Analyze the requirements for adding password reset functionality
```

#### general-purpose-assistant
General-purpose agent for diverse tasks requiring broad problem-solving capabilities

**Features**:
- Comprehensive problem analysis and solution
- Adherence to project conventions (TDD, no comments, layered architecture)
- Integration with Context7 MCP
- Flexible task execution across multiple domains

**Usage Example**:
```
Explain the overall project structure
Provide advice on improving development efficiency
```

### Slash Commands

#### `/exec-issue <issue number>`
Reads GitHub Issue and automates from implementation to PR creation

**Execution Steps**:
1. Create git worktree
2. Analyze Issue content
3. TDD implementation
4. PR creation

#### `/create-worktree <branch name>`
Creates and sets up a git worktree for task execution

**Execution Steps**:
1. Create git worktree with specified branch name
2. Copy environment files (.env)
3. Install dependencies

#### `/create-plan <task description>`
Creates an implementation plan and GitHub Issue using task-requirement-analyzer

**Execution Steps**:
1. Move to default branch and pull latest changes
2. Analyze task requirements using task-requirement-analyzer agent
3. Create GitHub Issue with implementation plan

#### `/fix-review-point <branch name>`
Address unresolved review comments on specified branch

**Execution Steps**:
1. Prepare git worktree
2. Retrieve review comments
3. TDD fixes
4. Resolve comments
5. Re-review request

#### `/fix-review-point-loop <branch name>`
Repeatedly address review comments until none remain (checks every 5 minutes)

#### `/general-task <task description>`
Execute general tasks using the general-purpose-assistant agent

**Execution Steps**:
1. Analyze task requirements
2. Select appropriate approach and tools
3. Execute task with Context7 MCP as needed
4. Validate results against project standards

### Skills

Skills are reusable prompts that can be invoked to perform specific tasks. Each skill can be invoked using the `/skill-name` syntax (e.g., `/check-library`, `/serena-mcp`).

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

#### `/create-git-worktree`
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

#### `/serena-mcp`
Expert guide for Serena MCP - semantic code analysis and editing

**Features**:
- Symbol-level code analysis (vs. reading entire files)
- Efficient code editing via symbol replacement
- Dependency analysis with referencing symbol search
- Pattern-based code search with regex support
- Project knowledge management via memories
- LSP symbol type filtering

**Usage Example**:
```
/serena-mcp
```

#### `/high-quality-commit`
Guides appropriate git commit strategies for code changes

**Features**:
- Squash strategy (default): Amend to existing commits
- New commit: For independent changes
- Interactive rebase: For reorganizing commit history
- Commit message guidelines (type, subject, body, footer)

**Usage Example**:
```
/high-quality-commit
```

#### `/read-github-issue`
Retrieves GitHub Issue content via gh command

**Features**:
- Fetches Issue title, body, comments, labels, and assignments
- Downloads images from Issues using gh-asset

**Usage Example**:
```
/read-github-issue
```

#### `/create-pr`
Creates GitHub Pull Request with proper template

**Features**:
- Uses `.github/PULL_REQUEST_TEMPLATE.md` for description
- Removes commented sections from template
- Includes `Closes #<issue number>` in description

**Usage Example**:
```
/create-pr
```

#### `/read-unresolved-pr-comments`
Retrieves unresolved PR comments via GitHub GraphQL API

**Features**:
- Fetches unresolved Review threads (code-specific comments, resolvable)
- Fetches Issue comments with code blocks (conversation tab, not resolvable)
- Returns PR metadata (number, title, URL, state, author, reviewers)
- JSON output format

**Usage Example**:
```
/read-unresolved-pr-comments
```

#### `/resolve-pr-comments`
Batch resolves PR Review threads via GitHub GraphQL API

**Features**:
- Automatically resolves all unresolved Review threads
- Uses resolveReviewThread mutation
- Displays resolve results for each thread
- Note: Issue comments (conversation tab) are not resolvable

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
├── getty104/                               # getty104 plugin
│   ├── .claude-plugin/
│   │   └── plugin.json                     # Plugin manifest (auto-generated)
│   ├── .mcp.json                           # MCP server configuration
│   ├── agents/                             # Agent definitions
│   │   ├── github-issue-implementer.md     # Issue implementation agent
│   │   ├── review-comment-implementer.md   # Review response agent
│   │   ├── pr-review-planner.md            # PR review analysis agent
│   │   ├── task-requirement-analyzer.md    # Task analysis agent
│   │   └── general-purpose-assistant.md    # General-purpose agent
│   ├── commands/                           # Command definitions
│   │   ├── exec-issue.md                   # Issue implementation command
│   │   ├── create-plan.md                  # Implementation plan command
│   │   ├── fix-review-point.md             # Review response command
│   │   ├── fix-review-point-loop.md        # Full review response command
│   │   └── general-task.md                 # General task execution command
│   ├── skills/                             # Skill definitions
│   │   ├── check-library/                  # Library documentation skill
│   │   │   ├── SKILL.md
│   │   │   └── examples.md
│   │   ├── create-git-worktree/            # Worktree creation skill
│   │   │   ├── SKILL.md
│   │   │   └── scripts/
│   │   │       └── create-worktree.sh
│   │   ├── serena-mcp/                     # Serena MCP expert guide
│   │   │   ├── SKILL.md
│   │   │   └── CLAUDE.md
│   │   ├── high-quality-commit/            # Commit strategy skill
│   │   │   ├── SKILL.md
│   │   │   ├── examples.md
│   │   │   └── reference.md
│   │   ├── read-github-issue/              # GitHub Issue retrieval skill
│   │   │   └── SKILL.md
│   │   ├── create-pr/                      # PR creation skill
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
  "name": "marketplace",
  "metadata": {
    "description": "getty104's marketplace",
    "version": "0.0.1"
  },
  "owner": {
    "name": "getty104"
  },
  "plugins": [
    {
      "name": "getty104",
      "source": "./getty104",
      "description": "This is a getty104's base tool set"
    }
  ]
}
```

## Development and Customization

### Adding Agents

Create `.md` files in `getty104/agents/`. Define `name`, `description`, `model`, and `color` in frontmatter:

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

### Adding Commands

Create `.md` files in `getty104/commands/` and describe the processing content:

```markdown
---
allowed-tools: Bash(git *), Context7(*)
description: Description of the command
---

Describe task description and execution steps in Markdown format.

## Step 1
Processing content...

## Step 2
Processing content...
```

Commands are executed as `/command-name arguments`, and can reference arguments via the `$ARGUMENTS` variable.

### Adding Skills

Create a directory in `getty104/skills/` with a `SKILL.md` file:

```markdown
---
name: skill-name
description: Description of what this skill does and when to use it
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

**Best Practices**:
- Make `description` clear and specific for auto-invocation by Claude Code
- Include `## Instructions` section with step-by-step guidance
- Place shell scripts in `scripts/` subdirectory for organization
- Reference scripts using relative paths: `bash scripts/my-script.sh`

### Configuring Hooks

Configure event handlers in `getty104/hooks/hooks.json`:

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
claude plugin validate getty104/
```

Run local tests:

```bash
claude plugin install ./getty104
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

Verify that command file names are correct. File names become command names as-is.

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
