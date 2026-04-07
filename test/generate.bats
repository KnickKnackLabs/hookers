#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/test_helper.bash"
  TEST_DIR="$(mktemp -d)"
  CATALOG_DIR="$TEST_DIR/catalog"
  STATE_FILE="$TEST_DIR/applied.json"
  mkdir -p "$CATALOG_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

make_hook() {
  local name="$1" on="$2" action="$3" command="${4:-}"
  local json="{\"name\":\"$name\",\"description\":\"Test hook\",\"on\":\"$on\",\"action\":\"$action\""
  [ -n "$command" ] && json="$json,\"command\":\"$command\""
  json="$json}"
  echo "$json" > "$CATALOG_DIR/${name}.json"
}

# Build state file with catalog path references
make_state() {
  local entries=""
  for name in "$@"; do
    [ -n "$entries" ] && entries="$entries,"
    entries="$entries{\"name\":\"$name\",\"catalog\":\"$CATALOG_DIR\"}"
  done
  echo "{\"applied\":[$entries]}" > "$STATE_FILE"
}

generate() {
  bash "$MISE_CONFIG_ROOT/scripts/generate-extension.sh" "$STATE_FILE"
}

@test "generates valid TypeScript structure" {
  make_hook "test" "session-start" "run" "echo hello"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'import type { ExtensionAPI }'* ]]
  [[ "$output" == *'export default function'* ]]
  [[ "$output" == *'}'* ]]
}

@test "maps session-start to session_start" {
  make_hook "test" "session-start" "run" "echo hello"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'session_start'* ]]
}

@test "maps before-prompt to before_agent_start" {
  make_hook "test" "before-prompt" "inject" "echo dashboard"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'before_agent_start'* ]]
}

@test "maps before-compact to session_before_compact" {
  make_hook "test" "before-compact" "block"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'session_before_compact'* ]]
}

@test "maps session-end to session_shutdown" {
  make_hook "test" "session-end" "run" "echo bye"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'session_shutdown'* ]]
}

@test "maps agent-stop to agent_end" {
  make_hook "test" "agent-stop" "run" "echo done"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'agent_end'* ]]
}

@test "maps before-tool to tool_call" {
  make_hook "test" "before-tool" "run" "echo checking"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'tool_call'* ]]
}

@test "maps after-tool to tool_result" {
  make_hook "test" "after-tool" "run" "echo done"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'tool_result'* ]]
}

@test "run action calls pi.exec" {
  make_hook "test" "session-start" "run" "echo hello"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'pi.exec("bash"'* ]]
  [[ "$output" == *'echo hello'* ]]
}

@test "inject action returns message" {
  make_hook "test" "before-prompt" "inject" "echo dashboard"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'message:'* ]]
  [[ "$output" == *'customType: "hookers:test"'* ]]
  [[ "$output" == *'result.stdout'* ]]
}

@test "inject action passes session ID to command" {
  make_hook "dash" "before-prompt" "inject" "hookers dashboard"
  make_state "dash"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'sessionManager.getSessionId()'* ]]
  [[ "$output" == *'HOOKERS_SESSION_ID'* ]]
}

@test "block action on before-compact returns cancel" {
  make_hook "test" "before-compact" "block"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'cancel: true'* ]]
}

@test "block action on before-tool with matcher generates regex check" {
  local json='{"name":"guard","description":"Test","on":"before-tool","action":"block","command":"echo check","matcher":"bash"}'
  echo "$json" > "$CATALOG_DIR/guard.json"
  make_state "guard"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'tool_call'* ]]
  [[ "$output" == *'RegExp'* ]]
  [[ "$output" == *'event.toolName'* ]]
  [[ "$output" == *'block: true'* ]]
}

@test "block action on before-tool without command blocks unconditionally" {
  local json='{"name":"blocker","description":"Test","on":"before-tool","action":"block"}'
  echo "$json" > "$CATALOG_DIR/blocker.json"
  make_state "blocker"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'tool_call'* ]]
  [[ "$output" == *'block: true'* ]]
}

@test "multiple hooks generate multiple handlers" {
  make_hook "hook1" "session-start" "run" "echo one"
  make_hook "hook2" "before-prompt" "inject" "echo two"
  make_state "hook1" "hook2"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'session_start'* ]]
  [[ "$output" == *'before_agent_start'* ]]
  [[ "$output" == *'echo one'* ]]
  [[ "$output" == *'echo two'* ]]
}

@test "inject action on non-before-prompt event fails" {
  make_hook "test" "session-start" "inject" "echo bad"
  make_state "test"

  run generate
  [ "$status" -ne 0 ]
  [[ "$output" == *"inject action only supported on before-prompt"* ]]
}

@test "fails on unknown event name" {
  make_hook "test" "invalid-event" "run" "echo bad"
  make_state "test"

  run generate
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown event"* ]]
}

@test "fails with empty applied list" {
  echo '{"applied":[]}' > "$STATE_FILE"

  run generate
  [ "$status" -ne 0 ]
  [[ "$output" == *"No hooks applied"* ]]
}

@test "fails with missing state file" {
  run bash "$MISE_CONFIG_ROOT/scripts/generate-extension.sh" "/nonexistent"
  [ "$status" -ne 0 ]
  [[ "$output" == *"State file not found"* ]]
}

@test "errors when catalog file is missing" {
  # State references a hook whose catalog file doesn't exist
  echo '{"applied":[{"name":"ghost","catalog":"/nonexistent/dir"}]}' > "$STATE_FILE"

  run generate
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "commands with special characters are properly escaped" {
  make_hook "test" "session-start" "run" "echo 'hello world' && date +%s > /tmp/test"
  make_state "test"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'echo'* ]]
  [[ "$output" == *'hello world'* ]]
}
