#!/usr/bin/env bats

setup() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TEST_HOME="$(mktemp -d)"
  TEST_CONFIG="$TEST_HOME/.config/hookers/dashboard.json"
  mkdir -p "$(dirname "$TEST_CONFIG")"
}

teardown() {
  rm -rf "$TEST_HOME"
}

run_dashboard() {
  HOOKERS_DASHBOARD_CONFIG="$TEST_CONFIG" mise -C "$REPO_DIR" run -q dashboard -- "$@"
}

@test "dashboard outputs nothing with no config" {
  rm -f "$TEST_CONFIG"
  run run_dashboard
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "dashboard outputs nothing with empty items" {
  echo '{"items": []}' > "$TEST_CONFIG"
  run run_dashboard
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "dashboard runs custom commands" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "test", "command": "echo hello"}]}
EOF
  run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dashboard] test: hello"* ]]
}

@test "dashboard handles multiple items with separator" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "a", "command": "echo one"},
  {"label": "b", "command": "echo two"}
]}
EOF
  run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"a: one | b: two"* ]]
}

@test "dashboard skips items that produce no output" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "a", "command": "echo one"},
  {"label": "empty", "command": "true"},
  {"label": "b", "command": "echo two"}
]}
EOF
  run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"a: one | b: two"* ]]
  [[ "$output" != *"empty"* ]]
}

@test "dashboard handles failing commands gracefully" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "ok", "command": "echo works"},
  {"label": "fail", "command": "exit 1"}
]}
EOF
  run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok: works"* ]]
}

@test "dashboard respects per-item timeout" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "slow", "command": "sleep 10 && echo done", "timeout": 1},
  {"label": "fast", "command": "echo quick"}
]}
EOF
  run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"fast: quick"* ]]
}

@test "provider runs bundled scripts" {
  run mise -C "$REPO_DIR" run -q provider -- git-branch
  [ "$status" -eq 0 ]
}

@test "provider rejects unknown name" {
  run mise -C "$REPO_DIR" run -q provider -- nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"No provider"* ]]
}
