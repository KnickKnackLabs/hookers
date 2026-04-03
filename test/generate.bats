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

generate() {
  bash "$MISE_CONFIG_ROOT/scripts/generate-extension.sh" "$STATE_FILE" "$CATALOG_DIR"
}

@test "generates valid TypeScript structure" {
  make_hook "test" "session-start" "run" "echo hello"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'import type { ExtensionAPI }'* ]]
  [[ "$output" == *'export default function'* ]]
  [[ "$output" == *'}'* ]]
}

@test "maps session-start to session_start" {
  make_hook "test" "session-start" "run" "echo hello"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'session_start'* ]]
}

@test "maps before-prompt to before_agent_start" {
  make_hook "test" "before-prompt" "inject" "echo dashboard"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'before_agent_start'* ]]
}

@test "maps before-compact to session_before_compact" {
  make_hook "test" "before-compact" "block"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'session_before_compact'* ]]
}

@test "maps session-end to session_shutdown" {
  make_hook "test" "session-end" "run" "echo bye"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'session_shutdown'* ]]
}

@test "maps agent-stop to agent_end" {
  make_hook "test" "agent-stop" "run" "echo done"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'agent_end'* ]]
}

@test "maps before-tool to tool_call" {
  make_hook "test" "before-tool" "run" "echo checking"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'tool_call'* ]]
}

@test "maps after-tool to tool_result" {
  make_hook "test" "after-tool" "run" "echo done"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'tool_result'* ]]
}

@test "run action calls pi.exec" {
  make_hook "test" "session-start" "run" "echo hello"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'pi.exec("bash"'* ]]
  [[ "$output" == *'echo hello'* ]]
}

@test "inject action returns message" {
  make_hook "test" "before-prompt" "inject" "echo dashboard"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'message:'* ]]
  [[ "$output" == *'customType: "hookers:test"'* ]]
  [[ "$output" == *'result.stdout'* ]]
}

@test "block action on before-compact returns cancel" {
  make_hook "test" "before-compact" "block"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'cancel: true'* ]]
}

@test "block action on before-tool with matcher generates regex check" {
  local json='{"name":"guard","description":"Test","on":"before-tool","action":"block","command":"echo check","matcher":"bash"}'
  echo "$json" > "$CATALOG_DIR/guard.json"
  echo '{"applied":["guard"]}' > "$STATE_FILE"

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
  echo '{"applied":["blocker"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'tool_call'* ]]
  [[ "$output" == *'block: true'* ]]
}

@test "multiple hooks generate multiple handlers" {
  make_hook "hook1" "session-start" "run" "echo one"
  make_hook "hook2" "before-prompt" "inject" "echo two"
  echo '{"applied":["hook1","hook2"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'session_start'* ]]
  [[ "$output" == *'before_agent_start'* ]]
  [[ "$output" == *'echo one'* ]]
  [[ "$output" == *'echo two'* ]]
}

@test "fails on unknown event name" {
  make_hook "test" "invalid-event" "run" "echo bad"
  echo '{"applied":["test"]}' > "$STATE_FILE"

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
  run bash "$MISE_CONFIG_ROOT/scripts/generate-extension.sh" "/nonexistent" "$CATALOG_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"State file not found"* ]]
}

@test "skips hooks not found in catalog" {
  make_hook "exists" "session-start" "run" "echo yes"
  echo '{"applied":["exists","missing"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  [[ "$output" == *'session_start'* ]]
  [[ "$output" == *"Warning"*"missing"* ]]
}

@test "commands with special characters are properly escaped" {
  make_hook "test" "session-start" "run" "echo 'hello world' && date +%s > /tmp/test"
  echo '{"applied":["test"]}' > "$STATE_FILE"

  run generate
  [ "$status" -eq 0 ]
  # The command should be JSON-escaped in the output
  [[ "$output" == *'echo'* ]]
  [[ "$output" == *'hello world'* ]]
}
