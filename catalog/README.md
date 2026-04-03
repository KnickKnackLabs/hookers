# Hook Catalog

Each JSON file defines a hook that can be applied to the agent harness (currently pi).

## Manifest Format

```json
{
  "name": "my-hook",
  "description": "What this hook does",
  "on": "session-start",
  "action": "run",
  "command": "my-tool do-something",
  "matcher": ""
}
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Unique hook identifier |
| `description` | yes | Human-readable description |
| `on` | yes | When the hook fires (see events below) |
| `action` | yes | What the hook does (see actions below) |
| `command` | no | Shell command to run (required for `run` and `inject` actions) |
| `matcher` | no | Filter pattern (e.g., tool name regex). Currently only used with `block` + `before-tool`. |

### Events

| Event | Description |
|-------|-------------|
| `session-start` | Session begins |
| `session-end` | Session ends |
| `before-prompt` | Before user prompt is processed |
| `before-compact` | Before context compaction |
| `before-tool` | Before tool execution |
| `after-tool` | After tool execution |
| `agent-stop` | Agent finishes responding |

### Actions

| Action | Description |
|--------|-------------|
| `run` | Fire-and-forget — run command for side effects |
| `inject` | Run command, inject stdout as agent context |
| `block` | Prevent the event from proceeding |
