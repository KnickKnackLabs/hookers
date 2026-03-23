#!/usr/bin/env bats

load dashboard-helpers

@test "wraps lines at --width" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "aaa", "command": "echo 111"},
  {"label": "bbb", "command": "echo 222"},
  {"label": "ccc", "command": "echo 333"}
]}
EOF
  run run_dashboard --no-color --width 35
  [ "$status" -eq 0 ]
  local line_count
  line_count=$(echo "$output" | wc -l)
  [ "$line_count" -gt 1 ]
}

@test "no wrap when everything fits in --width" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [
  {"label": "a", "command": "echo 1"}
]}
EOF
  run run_dashboard --no-color --width 80
  [ "$status" -eq 0 ]
  local line_count
  line_count=$(echo "$output" | wc -l)
  [ "$line_count" -eq 1 ]
}
