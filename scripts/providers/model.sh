#!/usr/bin/env bash
# Dashboard provider: active model from hook context
set -euo pipefail

if [ -n "${HOOKERS_MODEL:-}" ]; then
  echo "$HOOKERS_MODEL"
  exit 0
fi

if [ -n "${HOOKERS_MODEL_PROVIDER:-}" ] && [ -n "${HOOKERS_MODEL_ID:-}" ]; then
  echo "${HOOKERS_MODEL_PROVIDER}/${HOOKERS_MODEL_ID}"
fi
