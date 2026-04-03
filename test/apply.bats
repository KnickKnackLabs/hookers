#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  source "$BATS_TEST_DIRNAME/test_helper.bash"
  TEST_DIR="$(mktemp -d)"
  EXT_DIR="$TEST_DIR/extensions"
  STATE_DIR="$TEST_DIR/state"
  mkdir -p "$EXT_DIR" "$STATE_DIR"
  export HOOKERS_STATE_DIR="$STATE_DIR"
  export HOOKERS_EXT_DIR="$EXT_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- apply ---

@test "apply single hook" {
  run hookers apply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied 1"* ]]
  [ -f "$EXT_DIR/hookers.ts" ]
  grep -q "hookers:dashboard" "$EXT_DIR/hookers.ts"
}

@test "apply generates valid TypeScript" {
  run hookers apply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -eq 0 ]
  grep -q 'import type { ExtensionAPI }' "$EXT_DIR/hookers.ts"
  grep -q 'export default function' "$EXT_DIR/hookers.ts"
  grep -q 'pi.on(' "$EXT_DIR/hookers.ts"
}

@test "apply is idempotent" {
  run hookers apply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied 1"* ]]

  run hookers apply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"up to date"* ]]
}

@test "apply multiple hooks" {
  run hookers apply --extension-dir "$EXT_DIR" dashboard anti-compact
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied 2"* ]]
  grep -q "hookers:dashboard" "$EXT_DIR/hookers.ts"
  grep -q "anti-compact" "$EXT_DIR/hookers.ts"
}

@test "apply all hooks when no args given" {
  run hookers apply --extension-dir "$EXT_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied"* ]]
  [ -f "$EXT_DIR/hookers.ts" ]
}

@test "apply --dry-run does not create extension" {
  run hookers apply --extension-dir "$EXT_DIR" --dry-run dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would add"* ]]
  [ ! -f "$EXT_DIR/hookers.ts" ]
}

@test "apply rejects unknown hook name" {
  run hookers apply --extension-dir "$EXT_DIR" nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"No catalog entry"* ]]
}

@test "apply with --catalog adds external hooks" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/my-hook.json" <<'EOF'
{"name":"my-hook","description":"Test","on":"session-start","action":"run","command":"echo hello"}
EOF

  run hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" my-hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"Applied 1"* ]]
  grep -q "my-hook" "$EXT_DIR/hookers.ts"
  rm -rf "$EXTRA_DIR"
}

@test "apply rejects invalid catalog entries" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/bad.json" <<'EOF'
{"name":"bad","description":"Missing on field","action":"run","command":"echo"}
EOF

  run hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" bad
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing name, on, or action"* ]]
  rm -rf "$EXTRA_DIR"
}

@test "apply regenerates extension when catalog changes" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/updatable.json" <<'EOF'
{"name":"updatable","description":"Test","on":"session-start","action":"run","command":"echo v1"}
EOF

  hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" updatable
  grep -q 'echo v1' "$EXT_DIR/hookers.ts"

  # Update the catalog entry
  cat > "$EXTRA_DIR/updatable.json" <<'EOF'
{"name":"updatable","description":"Test","on":"session-start","action":"run","command":"echo v2"}
EOF

  # Re-apply — should regenerate with new command
  hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" updatable
  grep -q 'echo v2' "$EXT_DIR/hookers.ts"
  ! grep -q 'echo v1' "$EXT_DIR/hookers.ts"
  rm -rf "$EXTRA_DIR"
}

@test "apply does not update state when generator fails" {
  EXTRA_DIR="$(mktemp -d)"
  # inject on session-start is invalid — generator will fail
  cat > "$EXTRA_DIR/bad-inject.json" <<'EOF'
{"name":"bad-inject","description":"Test","on":"session-start","action":"inject","command":"echo oops"}
EOF

  run hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" bad-inject
  [ "$status" -ne 0 ]

  # State should not contain the failed hook
  run hookers list
  [[ "$output" == *"No hooks applied"* ]]
  rm -rf "$EXTRA_DIR"
}

@test "external catalog hooks survive re-apply without --catalog" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/ext-hook.json" <<'EOF'
{"name":"ext-hook","description":"External","on":"session-start","action":"run","command":"echo external"}
EOF

  # Apply both built-in and external hooks
  hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" dashboard ext-hook
  grep -q 'hookers:dashboard' "$EXT_DIR/hookers.ts"
  grep -q 'echo external' "$EXT_DIR/hookers.ts"

  # Re-apply built-in hook without --catalog — external hook should survive
  hookers apply --extension-dir "$EXT_DIR" dashboard
  grep -q 'hookers:dashboard' "$EXT_DIR/hookers.ts"
  grep -q 'echo external' "$EXT_DIR/hookers.ts"
  rm -rf "$EXTRA_DIR"
}

@test "list resolves external catalog hooks without --catalog" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/ext-hook.json" <<'EOF'
{"name":"ext-hook","description":"External","on":"session-start","action":"run","command":"echo external"}
EOF

  hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" ext-hook

  # list should find the hook via stored catalog path
  run hookers list
  [ "$status" -eq 0 ]
  [[ "$output" == *"ext-hook"* ]]
  [[ "$output" != *"not found"* ]]
  rm -rf "$EXTRA_DIR"
}

@test "unapply external hook without --catalog" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/ext-hook.json" <<'EOF'
{"name":"ext-hook","description":"External","on":"session-start","action":"run","command":"echo external"}
EOF

  hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" dashboard ext-hook

  # Unapply the external hook — no --catalog needed
  run hookers unapply --extension-dir "$EXT_DIR" ext-hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed 1"* ]]

  # Built-in hook should survive
  grep -q 'hookers:dashboard' "$EXT_DIR/hookers.ts"
  ! grep -q 'echo external' "$EXT_DIR/hookers.ts"
  rm -rf "$EXTRA_DIR"
}

@test "multiple external catalogs track independently" {
  EXTRA_A="$(mktemp -d)"
  EXTRA_B="$(mktemp -d)"
  cat > "$EXTRA_A/hook-a.json" <<'EOF'
{"name":"hook-a","description":"From A","on":"session-start","action":"run","command":"echo a"}
EOF
  cat > "$EXTRA_B/hook-b.json" <<'EOF'
{"name":"hook-b","description":"From B","on":"session-end","action":"run","command":"echo b"}
EOF

  hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_A" --catalog "$EXTRA_B" hook-a hook-b
  grep -q 'echo a' "$EXT_DIR/hookers.ts"
  grep -q 'echo b' "$EXT_DIR/hookers.ts"

  # Unapply one — other survives from its own catalog
  run hookers unapply --extension-dir "$EXT_DIR" hook-a
  [ "$status" -eq 0 ]
  ! grep -q 'echo a' "$EXT_DIR/hookers.ts"
  grep -q 'echo b' "$EXT_DIR/hookers.ts"
  rm -rf "$EXTRA_A" "$EXTRA_B"
}

@test "built-in catalog takes priority over external on name conflict" {
  EXTRA_DIR="$(mktemp -d)"
  # External catalog has a hook named 'dashboard' with different command
  cat > "$EXTRA_DIR/dashboard.json" <<'EOF'
{"name":"dashboard","description":"Shadow","on":"session-start","action":"run","command":"echo shadow"}
EOF

  # Built-in catalog is searched first, so built-in dashboard wins
  run hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" dashboard
  [ "$status" -eq 0 ]
  grep -q 'hookers dashboard' "$EXT_DIR/hookers.ts"
  ! grep -q 'echo shadow' "$EXT_DIR/hookers.ts"
  rm -rf "$EXTRA_DIR"
}

@test "list --json resolves external catalog hooks" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/ext-hook.json" <<'EOF'
{"name":"ext-hook","description":"External","on":"session-start","action":"run","command":"echo external"}
EOF

  hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" ext-hook

  run hookers list --json
  [ "$status" -eq 0 ]
  NAME=$(echo "$output" | jq -r '.[0].name')
  [ "$NAME" = "ext-hook" ]
  CMD=$(echo "$output" | jq -r '.[0].command')
  [ "$CMD" = "echo external" ]
  rm -rf "$EXTRA_DIR"
}

@test "list --json includes error entries for unreachable hooks" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/ext-hook.json" <<'EOF'
{"name":"ext-hook","description":"External","on":"session-start","action":"run","command":"echo external"}
EOF

  hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" dashboard ext-hook

  # Remove external catalog so ext-hook becomes unreachable
  rm -rf "$EXTRA_DIR"

  run --separate-stderr hookers list --json
  [ "$status" -eq 0 ]

  # dashboard should resolve normally
  DASH_NAME=$(echo "$output" | jq -r '[.[] | select(.name=="dashboard")][0].name')
  [ "$DASH_NAME" = "dashboard" ]

  # ext-hook should have an error entry
  EXT_ERR=$(echo "$output" | jq -r '[.[] | select(.name=="ext-hook")][0].error')
  [ "$EXT_ERR" = "catalog file not found" ]

  # stderr should warn about the missing catalog
  [[ "$stderr" == *"Warning"*"ext-hook"* ]]
}

# --- apply: event → pi mapping ---

@test "before-prompt maps to before_agent_start" {
  run hookers apply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -eq 0 ]
  grep -q 'before_agent_start' "$EXT_DIR/hookers.ts"
}

@test "before-compact maps to session_before_compact" {
  run hookers apply --extension-dir "$EXT_DIR" anti-compact
  [ "$status" -eq 0 ]
  grep -q 'session_before_compact' "$EXT_DIR/hookers.ts"
}

@test "session-start maps to session_start" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/starter.json" <<'EOF'
{"name":"starter","description":"Test","on":"session-start","action":"run","command":"echo started"}
EOF

  run hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" starter
  [ "$status" -eq 0 ]
  grep -q 'session_start' "$EXT_DIR/hookers.ts"
  rm -rf "$EXTRA_DIR"
}

# --- apply: action types ---

@test "inject action returns message from before_agent_start" {
  run hookers apply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -eq 0 ]
  grep -q 'message:' "$EXT_DIR/hookers.ts"
  grep -q 'content:' "$EXT_DIR/hookers.ts"
}

@test "block action returns cancel from session_before_compact" {
  run hookers apply --extension-dir "$EXT_DIR" anti-compact
  [ "$status" -eq 0 ]
  grep -q 'cancel: true' "$EXT_DIR/hookers.ts"
}

@test "run action calls pi.exec" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/runner.json" <<'EOF'
{"name":"runner","description":"Test","on":"session-start","action":"run","command":"echo hello"}
EOF

  run hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" runner
  [ "$status" -eq 0 ]
  grep -q 'pi.exec' "$EXT_DIR/hookers.ts"
  rm -rf "$EXTRA_DIR"
}

# --- unapply ---

@test "unapply removes hook" {
  hookers apply --extension-dir "$EXT_DIR" dashboard anti-compact

  run hookers unapply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed 1"* ]]
  [ -f "$EXT_DIR/hookers.ts" ]
  ! grep -q "hookers:dashboard" "$EXT_DIR/hookers.ts"
  grep -q "anti-compact" "$EXT_DIR/hookers.ts"
}

@test "unapply last hook removes extension" {
  hookers apply --extension-dir "$EXT_DIR" dashboard

  run hookers unapply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"extension removed"* ]]
  [ ! -f "$EXT_DIR/hookers.ts" ]
}

@test "unapply reports missing hooks" {
  run hookers unapply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"No hooks applied"* || "$output" == *"not applied"* ]]
}

@test "unapply --dry-run does not modify state" {
  hookers apply --extension-dir "$EXT_DIR" dashboard

  run hookers unapply --extension-dir "$EXT_DIR" --dry-run dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would remove"* ]]

  run hookers list
  [[ "$output" == *"dashboard"* ]]
}

@test "unapply does not update state when regeneration fails" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/ext-hook.json" <<'EOF'
{"name":"ext-hook","description":"External","on":"session-start","action":"run","command":"echo external"}
EOF

  hookers apply --extension-dir "$EXT_DIR" --catalog "$EXTRA_DIR" dashboard ext-hook

  # Delete the external catalog so regeneration fails
  rm -rf "$EXTRA_DIR"

  # Unapply dashboard — regeneration needs ext-hook's catalog, which is gone
  run hookers unapply --extension-dir "$EXT_DIR" dashboard
  [ "$status" -ne 0 ]

  # State should still have both hooks
  run hookers list
  [[ "$output" == *"dashboard"* ]]
  [[ "$output" == *"ext-hook"* ]]
}

# --- list ---

@test "list shows applied hooks" {
  hookers apply --extension-dir "$EXT_DIR" dashboard anti-compact

  run hookers list
  [ "$status" -eq 0 ]
  [[ "$output" == *"dashboard"* ]]
  [[ "$output" == *"anti-compact"* ]]
}

@test "list --json outputs valid JSON" {
  hookers apply --extension-dir "$EXT_DIR" dashboard

  run hookers list --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null 2>&1
  NAME=$(echo "$output" | jq -r '.[0].name')
  [ "$NAME" = "dashboard" ]
}

@test "list shows nothing when no hooks applied" {
  run hookers list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No hooks applied"* ]]
}

# --- full cycle ---

@test "full cycle: apply, list, unapply, re-apply" {
  run hookers apply --extension-dir "$EXT_DIR" dashboard
  [[ "$output" == *"Applied 1"* ]]

  run hookers list
  [[ "$output" == *"dashboard"* ]]

  run hookers unapply --extension-dir "$EXT_DIR" dashboard
  [[ "$output" == *"Removed 1"* ]]

  run hookers list
  [[ "$output" == *"No hooks applied"* ]]

  run hookers apply --extension-dir "$EXT_DIR" dashboard
  [[ "$output" == *"Applied 1"* ]]
}
