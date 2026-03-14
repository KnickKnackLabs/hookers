#!/usr/bin/env bash
# Dashboard script — reads config, runs commands, outputs compact status line.
# Config file: ~/.config/hookers/dashboard.json
# Output goes to stdout, which UserPromptSubmit injects into agent context.

set -eu

CONFIG="${HOOKERS_DASHBOARD_CONFIG:-$HOME/.config/hookers/dashboard.json}"

if [ ! -f "$CONFIG" ]; then
  exit 0
fi

ITEM_COUNT=$(jq '.items | length' "$CONFIG")
if [ "$ITEM_COUNT" -eq 0 ]; then
  exit 0
fi

PARTS=()
for ((i=0; i<ITEM_COUNT; i++)); do
  LABEL=$(jq -r --argjson i "$i" '.items[$i].label' "$CONFIG")
  CMD=$(jq -r --argjson i "$i" '.items[$i].command' "$CONFIG")
  TIMEOUT=$(jq -r --argjson i "$i" '.items[$i].timeout // 5' "$CONFIG")

  # Run command with timeout, capture output, swallow errors
  VALUE=$(timeout "${TIMEOUT}s" bash -c "$CMD" 2>/dev/null | tr -d '\n' || echo "?")

  if [ -n "$VALUE" ]; then
    PARTS+=("${LABEL}: ${VALUE}")
  fi
done

if [ ${#PARTS[@]} -gt 0 ]; then
  OUTPUT=""
  for ((i=0; i<${#PARTS[@]}; i++)); do
    if [ $i -gt 0 ]; then OUTPUT+=" | "; fi
    OUTPUT+="${PARTS[$i]}"
  done
  echo "[dashboard] $OUTPUT"
fi
