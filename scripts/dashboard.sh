#!/usr/bin/env bash
# Dashboard script — reads config, runs providers in parallel, outputs compact status line.
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

# Create temp dir for parallel provider results
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Launch all providers in parallel
for ((i=0; i<ITEM_COUNT; i++)); do
  CMD=$(jq -r --argjson i "$i" '.items[$i].command' "$CONFIG")
  TIMEOUT=$(jq -r --argjson i "$i" '.items[$i].timeout // 5' "$CONFIG")
  (
    VALUE=$(timeout "${TIMEOUT}s" bash -c "$CMD" 2>/dev/null | tr -d '\n' || echo "?")
    echo -n "$VALUE" > "$TMPDIR/$i"
  ) &
done
wait

# Collect results in order
PARTS=()
for ((i=0; i<ITEM_COUNT; i++)); do
  LABEL=$(jq -r --argjson i "$i" '.items[$i].label' "$CONFIG")
  VALUE=""
  [ -f "$TMPDIR/$i" ] && VALUE=$(cat "$TMPDIR/$i")

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
