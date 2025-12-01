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
claude plugin install getty104
```

### MCP Configuration

The `.mcp.json` included in the plugin automatically configures the following MCP servers:
- **chrome-devtools**: Browser automation and DevTools integration
- **serena**: Codebase analysis and semantic operations
- **context7**: Library documentation retrieval (HTTP-based, no API key required)
- **next-devtools**: Next.js development tools and documentation
- **shadcn**: shadcn/ui component library integration

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

#### task-requirement-analyzer
Agent specialized in analyzing task requirements and creating implementation plans

**Features**:
- Deep analysis of task requirements (explicit and implicit)
- Codebase exploration using Serena MCP
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
- Integration with Serena and Context7 MCPs
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
3. Copy Serena memories
4. Install dependencies

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
3. Execute task with Serena MCP and Context7 MCP as needed
4. Validate results against project standards

### Skills

Skills are reusable prompts that can be invoked to perform specific tasks.

#### check-library
Retrieves library documentation using appropriate MCP servers

**Features**:
- Next.js: Uses next-devtools MCP
- shadcn/ui: Uses shadcn MCP
- Other libraries: Uses context7 MCP

**Usage**: Invoke when you need to check library documentation or usage

#### create-git-worktree
Automates git worktree creation and environment setup

**Features**:
- Creates worktree in `.git-worktrees/` directory
- Automatically converts `/` to `-` in branch names
- Copies .env and Serena memories
- Reuses existing worktrees

#### web-search
Advanced web search using gemini command

**Features**:
- Natural language queries
- Complex question handling
- Source citation

**Usage**: Preferred over default WebSearch tool for comprehensive searches

#### high-quality-commit
Guides appropriate git commit strategies

**Features**:
- Squash strategy (default): Amend to existing commits
- New commit: For independent changes
- Interactive rebase: For reorganizing commit history

#### read-unresolved-pr-comments
Retrieves unresolved PR comments via GitHub GraphQL API

**Features**:
- Fetches unresolved Review threads (code-specific comments)
- Fetches Issue comments with code blocks
- Returns PR metadata (number, title, URL, state, author, reviewers)

#### resolve-pr-comments
Batch resolves PR Review threads via GitHub GraphQL API

**Features**:
- Automatically resolves all unresolved Review threads
- Displays resolve results for each thread

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
│   │   ├── task-requirement-analyzer.md    # Task analysis agent
│   │   └── general-purpose-assistant.md    # General-purpose agent
│   ├── commands/                           # Command definitions
│   │   ├── exec-issue.md                   # Issue implementation command
│   │   ├── create-worktree.md              # Worktree creation command
│   │   ├── create-plan.md                  # Implementation plan command
│   │   ├── fix-review-point.md             # Review response command
│   │   ├── fix-review-point-loop.md        # Full review response command
│   │   └── general-task.md                 # General task execution command
│   ├── skills/                             # Skill definitions
│   │   ├── check-library/                  # Library documentation skill
│   │   ├── create-git-worktree/            # Worktree creation skill
│   │   ├── web-search/                     # Web search skill
│   │   ├── high-quality-commit/            # Commit strategy skill
│   │   ├── read-unresolved-pr-comments/    # PR comment retrieval skill
│   │   └── resolve-pr-comments/            # PR comment resolution skill
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
allowed-tools: Bash(git *), Serena(*), Context7(*)
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

Skills can include:
- `SKILL.md`: Main skill definition
- `scripts/`: Shell scripts for automation
- `examples.md`: Usage examples
- `reference.md`: Additional reference material

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
