#!/usr/bin/env bats

load dashboard-helpers

run_debug() {
  HOOKERS_DEBUG=1 HOOKERS_DASHBOARD_DEBUG_LOG="$TEST_HOME/debug.log" \
    run run_dashboard
}

run_debug_cached() {
  HOOKERS_DEBUG=1 HOOKERS_DASHBOARD_DEBUG_LOG="$TEST_HOME/debug.log" \
    HOOKERS_SESSION_ID="test-session" HOOKERS_DASHBOARD_CACHE_DIR="$TEST_HOME/cache" \
    run run_dashboard
}

@test "debug log created when HOOKERS_DEBUG=1" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "fast", "command": "echo ok"}]}
EOF
  run_debug
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/debug.log" ]
  grep -q "dashboard start" "$TEST_HOME/debug.log"
  grep -q "dashboard done" "$TEST_HOME/debug.log"
}

@test "debug log not created when HOOKERS_DEBUG is unset" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "fast", "command": "echo ok"}]}
EOF
  HOOKERS_DASHBOARD_DEBUG_LOG="$TEST_HOME/debug.log" run run_dashboard
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_HOME/debug.log" ]
}

@test "debug log shows no-cache for uncached providers" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "fast", "command": "echo ok"}]}
EOF
  run_debug
  [ "$status" -eq 0 ]
  grep -q "fast: no-cache" "$TEST_HOME/debug.log"
}

@test "debug log shows cache hit and miss" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "cached", "command": "echo val", "cache": 60}]}
EOF
  # First run — miss
  run_debug_cached
  [ "$status" -eq 0 ]
  grep -q "cached: miss" "$TEST_HOME/debug.log"

  # Second run — hit
  run_debug_cached
  grep -q "cached: hit" "$TEST_HOME/debug.log"
}

@test "debug log shows duration in ms" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "fast", "command": "echo ok"}]}
EOF
  run_debug
  [ "$status" -eq 0 ]
  grep -q "ms" "$TEST_HOME/debug.log"
}

@test "debug log shows total wall time" {
  cat > "$TEST_CONFIG" << 'EOF'
{"items": [{"label": "fast", "command": "echo ok"}]}
EOF
  run_debug
  [ "$status" -eq 0 ]
  grep -qE "dashboard done: [0-9]+ms" "$TEST_HOME/debug.log"
}
