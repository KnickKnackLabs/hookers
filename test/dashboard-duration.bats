#!/usr/bin/env bats

load dashboard-helpers

@test "--no-duration hides all durations" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "slow", "command": "sleep 1 && echo done"}]}
EOF
  run run_dashboard --no-duration
  [ "$status" -eq 0 ]
  [[ "$output" != *"("* ]]
}

@test "shows duration above threshold" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "slow", "command": "sleep 1 && echo done"}]}
EOF
  run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *"done ("*"s)"* ]]
}

@test "hides duration below threshold" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "fast", "command": "echo quick"}]}
EOF
  HOOKERS_DASHBOARD_DURATION_THRESHOLD=10 run run_dashboard
  [ "$status" -eq 0 ]
  [[ "$output" != *"("* ]]
}
