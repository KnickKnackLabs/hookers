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

NO_PREFIX="${HOOKERS_DASHBOARD_NO_PREFIX:-}"
NO_LABELS="${HOOKERS_DASHBOARD_NO_LABELS:-}"
NO_DURATION="${HOOKERS_DASHBOARD_NO_DURATION:-}"
DURATION_THRESHOLD="${HOOKERS_DASHBOARD_DURATION_THRESHOLD:-1}"

# Color: explicit setting > TTY detection
if [ "${HOOKERS_DASHBOARD_COLOR:-}" = "1" ]; then
  USE_COLOR=1
elif [ "${HOOKERS_DASHBOARD_COLOR:-}" = "0" ]; then
  USE_COLOR=0
elif [ -t 1 ]; then
  USE_COLOR=1
else
  USE_COLOR=0
fi

# Max width: explicit setting > terminal width > 0 (no wrap)
MAX_WIDTH="${HOOKERS_DASHBOARD_WIDTH:-0}"
if [ "$MAX_WIDTH" = "0" ] && [ -t 1 ]; then
  MAX_WIDTH=$(tput cols 2>/dev/null || echo 0)
fi

# ANSI codes
if [ "$USE_COLOR" = "1" ]; then
  DIM="\033[2m"
  RESET="\033[0m"
else
  DIM=""
  RESET=""
fi

# Create temp dir for parallel provider results
RESULTS_DIR=$(mktemp -d)
trap 'rm -rf "$RESULTS_DIR"' EXIT

# Launch all providers in parallel
for ((i=0; i<ITEM_COUNT; i++)); do
  CMD=$(jq -r --argjson i "$i" '.items[$i].command' "$CONFIG")
  TIMEOUT=$(jq -r --argjson i "$i" '.items[$i].timeout // 5' "$CONFIG")
  (
    START_S=$(date +%s)
    VALUE=$(timeout "${TIMEOUT}s" bash -c "$CMD" 2>/dev/null | tr -d '\n')
    END_S=$(date +%s)
    ELAPSED_S=$((END_S - START_S))
    echo -n "$VALUE" > "$RESULTS_DIR/$i.value.tmp"
    echo -n "$ELAPSED_S" > "$RESULTS_DIR/$i.dur.tmp"
    mv "$RESULTS_DIR/$i.value.tmp" "$RESULTS_DIR/$i.value"
    mv "$RESULTS_DIR/$i.dur.tmp" "$RESULTS_DIR/$i.dur"
  ) &
done
wait

# Collect results in order — store label, value, duration separately for rendering
LABELS=()
VALUES=()
DURATIONS=()
for ((i=0; i<ITEM_COUNT; i++)); do
  LABEL=$(jq -r --argjson i "$i" '.items[$i].label' "$CONFIG")
  VALUE=""
  [ -f "$RESULTS_DIR/$i.value" ] && VALUE=$(cat "$RESULTS_DIR/$i.value")

  if [ -n "$VALUE" ]; then
    DUR=""
    if [ "$NO_DURATION" != "1" ] && [ -f "$RESULTS_DIR/$i.dur" ]; then
      SECS=$(cat "$RESULTS_DIR/$i.dur")
      if [ "$SECS" -ge "$DURATION_THRESHOLD" ]; then
        DUR="(${SECS}s)"
      fi
    fi

    LABELS+=("$LABEL")
    VALUES+=("$VALUE")
    DURATIONS+=("$DUR")
  fi
done

if [ ${#VALUES[@]} -eq 0 ]; then
  exit 0
fi

# Render a single item (plain text, no ANSI) for width calculation
render_plain() {
  local idx=$1
  local part=""
  if [ "$NO_LABELS" != "1" ]; then
    part="${LABELS[$idx]}: "
  fi
  part+="${VALUES[$idx]}"
  if [ -n "${DURATIONS[$idx]}" ]; then
    part+=" ${DURATIONS[$idx]}"
  fi
  echo -n "$part"
}

# Render a single item with optional color (DIM/RESET are empty when color is off)
render_item() {
  local idx=$1
  if [ "$NO_LABELS" != "1" ]; then
    printf "${DIM}%s:${RESET} %s" "${LABELS[$idx]}" "${VALUES[$idx]}"
  else
    printf "%s" "${VALUES[$idx]}"
  fi
  if [ -n "${DURATIONS[$idx]}" ]; then
    printf " ${DIM}%s${RESET}" "${DURATIONS[$idx]}"
  fi
}

# Build output with optional line wrapping
SEP=" | "
SEP_LEN=${#SEP}
PREFIX=""
if [ "$NO_PREFIX" != "1" ]; then
  PREFIX="[dashboard] "
fi
PREFIX_LEN=${#PREFIX}

# Default to 1000 columns when no width is set — wide enough to never wrap
# in practice (terminals rarely exceed ~500 cols), but still a finite number
# so the rendering logic has a single code path.
if [ "$MAX_WIDTH" -le 0 ]; then
  MAX_WIDTH=1000
fi

LINE_LEN=$PREFIX_LEN
FIRST_ON_LINE=1

if [ "$USE_COLOR" = "1" ]; then
  printf "${DIM}%s${RESET}" "$PREFIX"
else
  printf "%s" "$PREFIX"
fi

for ((i=0; i<${#VALUES[@]}; i++)); do
  ITEM_PLAIN=$(render_plain "$i")
  ITEM_LEN=${#ITEM_PLAIN}

  if [ "$FIRST_ON_LINE" = "1" ]; then
    render_item "$i"
    LINE_LEN=$((LINE_LEN + ITEM_LEN))
    FIRST_ON_LINE=0
  elif [ $((LINE_LEN + SEP_LEN + ITEM_LEN)) -le "$MAX_WIDTH" ]; then
    if [ "$USE_COLOR" = "1" ]; then
      printf "${DIM} | ${RESET}"
    else
      printf " | "
    fi
    render_item "$i"
    LINE_LEN=$((LINE_LEN + SEP_LEN + ITEM_LEN))
  else
    printf "\n"
    if [ "$USE_COLOR" = "1" ]; then
      printf "${DIM}%s${RESET}" "$PREFIX"
    else
      printf "%s" "$PREFIX"
    fi
    render_item "$i"
    LINE_LEN=$((PREFIX_LEN + ITEM_LEN))
  fi
done
printf "\n"
