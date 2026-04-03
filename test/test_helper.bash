#!/usr/bin/env bash
# Shared test helpers for hookers BATS tests.
# Provides a hookers() wrapper that calls tasks through mise.

if [ -z "${MISE_CONFIG_ROOT:-}" ]; then
  echo "MISE_CONFIG_ROOT not set — run tests via: mise run test" >&2
  exit 1
fi

hookers() {
  cd "$MISE_CONFIG_ROOT" && mise run -q "$@"
}
export -f hookers
