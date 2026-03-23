#!/usr/bin/env bash
# Shared setup/teardown/helpers for dashboard tests

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
