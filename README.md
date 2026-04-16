<div align="center">

# hookers

**Agent hooks infrastructure.**

A catalog of hooks for Claude Code (and eventually other agent clients).
Apply what you need. Skip what you don't.

![shell: bash](https://img.shields.io/badge/shell-bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![runtime: mise](https://img.shields.io/badge/runtime-mise-7c3aed?style=flat)](https://mise.jdx.dev)
![tests: 24 passing](https://img.shields.io/badge/tests-24%20passing-brightgreen?style=flat)
![hooks: 3](https://img.shields.io/badge/hooks-3-blue?style=flat)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat)](LICENSE)

</div>

## Install

```bash
shiv install hookers
```

## Quick start

```bash
# See available hooks
hookers catalog

# Apply hooks to your Claude Code settings
hookers apply session-id dashboard

# Apply all hooks
hookers apply

# Remove a hook
hookers unapply dashboard

# See what's installed
hookers list
```

## Hook catalog

Each hook lives as a self-describing JSON file in `catalog/`. Apply selectively — only install what you need.

| Hook | Description |
| --- | --- |
| `anti-compact` | Kill the session when context compaction is triggered — compaction loses context, better to end and start fresh |
| `dashboard` | Inject a configurable status dashboard into the agent's context on each user prompt |
| `session-id` | Expose CLAUDE_CODE_SESSION_ID as an environment variable on session start |

## Dashboard

The `dashboard` hook injects a compact status line into your agent's context on every prompt. Configure what data to show via `~/.config/hookers/dashboard.json`:

```json
{
  "items": [
    {"label": "model", "command": "hookers provider model"},
    {"label": "mail", "command": "hookers provider unread-mail"},
    {"label": "branch", "command": "hookers provider git-branch"},
    {"label": "gh-token", "command": "hookers provider gh-token-expiry"},
    {"label": "dirty", "command": "hookers provider dirty-files"},
    {"label": "time", "command": "hookers provider time"}
  ]
}
```

Output looks like:

```
[dashboard] model: openai/gpt-5.4 | mail: 84 | branch: main | gh-token: 5d | dirty: 3 | time: 14:30 UTC
```

When the hook runner provides model context (for example in pi), `hookers provider model` can render the active model. Providers run in parallel with per-item timeouts. Items that produce no output are silently skipped. See [escort](https://github.com/KnickKnackLabs/escort) for richer providers designed for agent workflows.

## Bundled providers

| Provider | Description |
| --- | --- |
| `hookers provider dirty-files` | count of uncommitted changes |
| `hookers provider gh-token-expiry` | GitHub token days until expiry |
| `hookers provider git-branch` | current git branch |
| `hookers provider model` | active model from hook context |
| `hookers provider time` | current time (UTC) |
| `hookers provider unread-mail` | unread email count |

## How it works

Hooks are identified by a bash comment marker (`# hookers:<name>`) embedded in the command. This enables:

- **Idempotent apply** — re-applying detects unchanged hooks and skips them
- **Clean updates** — changed hooks are replaced, not duplicated
- **Reliable unapply** — removal by catalog name, not by exact command string

Hooks are written to Claude Code's `settings.json` (user scope by default). Use `--scope project` or `--scope local` for per-project hooks.

## Commands

| Command | Description |
| --- | --- |
| `hookers add` | Add a hook to Claude Code settings |
| `hookers apply` | Apply hooks from the catalog to Claude Code settings |
| `hookers catalog` | List available hooks in the catalog |
| `hookers dashboard` | Run the status dashboard (outputs a compact status line) |
| `hookers list` | List configured Claude Code hooks |
| `hookers provider` | Run a dashboard data provider |
| `hookers remove` | Remove a hook from Claude Code settings |
| `hookers unapply` | Remove hooks installed from the catalog |

## Development

```bash
git clone https://github.com/KnickKnackLabs/hookers.git
cd hookers && mise trust && mise install
mise run test
```

Tests use [BATS](https://github.com/bats-core/bats-core) — 24 tests across 3 suites covering dashboard, apply, catalog.

<div align="center">

## License

MIT

This README was created using [readme](https://github.com/KnickKnackLabs/readme).

</div>
