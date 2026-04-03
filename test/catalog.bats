#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/test_helper.bash"
}

@test "catalog lists all hooks" {
  run hookers catalog
  [ "$status" -eq 0 ]
  [[ "$output" == *"anti-compact"* ]]
  [[ "$output" == *"dashboard"* ]]
}

@test "catalog --json outputs valid JSON" {
  run hookers catalog --json
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null 2>&1
}

@test "each catalog entry has required fields" {
  run hookers catalog --json
  [ "$status" -eq 0 ]
  INVALID=$(echo "$output" | jq '[.[] | select(.name and .description and .on and .action | not)] | length')
  [ "$INVALID" -eq 0 ]
}

@test "catalog entries use valid event names" {
  run hookers catalog --json
  [ "$status" -eq 0 ]
  VALID_EVENTS="session-start session-end before-prompt before-compact before-tool after-tool agent-stop"
  INVALID=$(echo "$output" | jq --arg valid "$VALID_EVENTS" '
    ($valid | split(" ")) as $allowed |
    [.[] | select(.on | IN($allowed[]) | not)] | length
  ')
  [ "$INVALID" -eq 0 ]
}

@test "catalog entries use valid action types" {
  run hookers catalog --json
  [ "$status" -eq 0 ]
  INVALID=$(echo "$output" | jq '
    ["run", "inject", "block"] as $allowed |
    [.[] | select(.action | IN($allowed[]) | not)] | length
  ')
  [ "$INVALID" -eq 0 ]
}

@test "run and inject actions have a command" {
  run hookers catalog --json
  [ "$status" -eq 0 ]
  MISSING=$(echo "$output" | jq '
    [.[] | select((.action == "run" or .action == "inject") and (.command | length == 0))] | length
  ')
  [ "$MISSING" -eq 0 ]
}

@test "catalog accepts --catalog for additional directories" {
  EXTRA_DIR="$(mktemp -d)"
  cat > "$EXTRA_DIR/test-hook.json" <<'EOF'
{"name":"test-hook","description":"A test hook","on":"session-start","action":"run","command":"echo test"}
EOF

  run hookers catalog --json --catalog "$EXTRA_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test-hook"* ]]
  rm -rf "$EXTRA_DIR"
}
