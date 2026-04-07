#!/usr/bin/env bash
# Dashboard script — reads config, runs providers in parallel, outputs compact status line.
# Config file: ~/.config/hookers/dashboard.json
# Output goes to stdout, which UserPromptSubmit injects into agent context.

set -euo pipefail

# HOOKERS_CWD is expected to be set by the caller when workspace context
# matters (e.g. Claude Code hooks extract .cwd from stdin JSON before invoking hookers,
# since the shiv chain consumes stdin). Providers use this to operate on the workspace
# directory rather than their own repo dir.

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

# Debug logging. Always writes to the log file for now (diagnosing latency).
# TODO: gate behind HOOKERS_DEBUG=1 once investigation is done.
DEBUG_LOG="${HOOKERS_DASHBOARD_DEBUG_LOG:-${XDG_CACHE_HOME:-$HOME/.cache}/hookers/dashboard-debug.log}"
mkdir -p "$(dirname "$DEBUG_LOG")"

# Write a debug log line with timestamp.
# Usage: debug_log "message"
debug_log() {
  if [ -n "$DEBUG_LOG" ]; then
    printf "%s %s\n" "$(date '+%H:%M:%S')" "$1" >> "$DEBUG_LOG"
  fi
}

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

# Cache: session-scoped provider result caching.
# Requires HOOKERS_SESSION_ID to be set (by the agent harness via the extension).
# Per-item TTL via "cache": <seconds> in config. Items without "cache" always run.
SESSION_ID="${HOOKERS_SESSION_ID:-}"
CACHE_DIR=""
if [ -n "$SESSION_ID" ]; then
  CACHE_BASE="${HOOKERS_DASHBOARD_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/hookers/dashboard}"
  CACHE_DIR="$CACHE_BASE/$SESSION_ID"
  mkdir -p "$CACHE_DIR"
  # Opportunistic prune: remove session cache dirs older than 7 days
  find "$CACHE_BASE" -maxdepth 1 -type d -mtime +7 -not -path "$CACHE_BASE" -exec rm -rf {} + 2>/dev/null || true
fi

# Generate a cache key from a command string.
# Uses md5 (macOS) or md5sum (Linux), falling back to shasum.
cache_key() {
  local cmd="$1"
  if command -v md5 >/dev/null 2>&1; then
    echo -n "$cmd" | md5
  elif command -v md5sum >/dev/null 2>&1; then
    echo -n "$cmd" | md5sum | cut -d' ' -f1
  else
    echo -n "$cmd" | shasum -a 256 | cut -d' ' -f1
  fi
}

# Create temp dir for parallel provider results
RESULTS_DIR=$(mktemp -d)
trap 'rm -rf "$RESULTS_DIR"' EXIT

DASH_START_MS=$(($(date +%s%N 2>/dev/null || echo "$(date +%s)000000000") / 1000000))
debug_log "--- dashboard start (session=${SESSION_ID:-none}) ---"

# Launch all providers in parallel
for ((i=0; i<ITEM_COUNT; i++)); do
  CMD=$(jq -r --argjson i "$i" '.items[$i].command' "$CONFIG")
  TIMEOUT=$(jq -r --argjson i "$i" '.items[$i].timeout // 5' "$CONFIG")
  CACHE_TTL=$(jq -r --argjson i "$i" '.items[$i].cache // 0' "$CONFIG")
  (
    # Check cache
    if [ -n "$CACHE_DIR" ] && [ "$CACHE_TTL" -gt 0 ]; then
      KEY=$(cache_key "$i:$CMD")
      CACHE_FILE="$CACHE_DIR/$KEY"
      if [ -f "$CACHE_FILE" ]; then
        NOW=$(date +%s)
        FILE_MOD=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
        AGE=$((NOW - FILE_MOD))
        if [ "$AGE" -lt "$CACHE_TTL" ]; then
          # Cache hit
          cat "$CACHE_FILE" > "$RESULTS_DIR/$i.value.tmp"
          echo -n "0" > "$RESULTS_DIR/$i.durms.tmp"
          echo -n "hit" > "$RESULTS_DIR/$i.cache.tmp"
          echo -n "$AGE" > "$RESULTS_DIR/$i.age.tmp"
          echo -n "$CACHE_TTL" > "$RESULTS_DIR/$i.ttl.tmp"
          mv "$RESULTS_DIR/$i.value.tmp" "$RESULTS_DIR/$i.value"
          mv "$RESULTS_DIR/$i.durms.tmp" "$RESULTS_DIR/$i.durms"
          mv "$RESULTS_DIR/$i.cache.tmp" "$RESULTS_DIR/$i.cache"
          mv "$RESULTS_DIR/$i.age.tmp" "$RESULTS_DIR/$i.age"
          mv "$RESULTS_DIR/$i.ttl.tmp" "$RESULTS_DIR/$i.ttl"
          exit 0
        fi
      fi
    fi

    # Cache miss or no caching — run the provider
    START_NS=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
    VALUE=$(timeout "${TIMEOUT}s" bash -c "$CMD" 2>/dev/null | tr -d '\n')
    END_NS=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
    ELAPSED_MS=$(( (END_NS - START_NS) / 1000000 ))
    echo -n "$VALUE" > "$RESULTS_DIR/$i.value.tmp"
    echo -n "$ELAPSED_MS" > "$RESULTS_DIR/$i.durms.tmp"
    mv "$RESULTS_DIR/$i.value.tmp" "$RESULTS_DIR/$i.value"
    mv "$RESULTS_DIR/$i.durms.tmp" "$RESULTS_DIR/$i.durms"

    # Write debug metadata for collection after wait
    if [ -n "$CACHE_DIR" ] && [ "$CACHE_TTL" -gt 0 ]; then
      echo -n "miss" > "$RESULTS_DIR/$i.cache.tmp"
      echo -n "$CACHE_TTL" > "$RESULTS_DIR/$i.ttl.tmp"
      mv "$RESULTS_DIR/$i.cache.tmp" "$RESULTS_DIR/$i.cache"
      mv "$RESULTS_DIR/$i.ttl.tmp" "$RESULTS_DIR/$i.ttl"
    else
      echo -n "no-cache" > "$RESULTS_DIR/$i.cache.tmp"
      mv "$RESULTS_DIR/$i.cache.tmp" "$RESULTS_DIR/$i.cache"
    fi

    # Write to cache (atomic via tmp+mv) — skip empty results so
    # transient failures don't suppress retries until TTL expires.
    if [ -n "$CACHE_DIR" ] && [ "$CACHE_TTL" -gt 0 ] && [ -n "$VALUE" ]; then
      KEY=$(cache_key "$i:$CMD")
      echo -n "$VALUE" > "$CACHE_DIR/$KEY.tmp" && mv "$CACHE_DIR/$KEY.tmp" "$CACHE_DIR/$KEY"
    fi
  ) &
done
wait

# Log per-provider debug info
HIT_COUNT=0
MISS_COUNT=0
NOCACHE_COUNT=0
for ((i=0; i<ITEM_COUNT; i++)); do
  if [ -n "$DEBUG_LOG" ]; then
    DLABEL=$(jq -r --argjson i "$i" '.items[$i].label' "$CONFIG")
    DCACHE=""; [ -f "$RESULTS_DIR/$i.cache" ] && DCACHE=$(cat "$RESULTS_DIR/$i.cache")
    DDUR="?"; [ -f "$RESULTS_DIR/$i.durms" ] && DDUR=$(cat "$RESULTS_DIR/$i.durms")
    DAGE=""; [ -f "$RESULTS_DIR/$i.age" ] && DAGE=$(cat "$RESULTS_DIR/$i.age")
    DTTL=""; [ -f "$RESULTS_DIR/$i.ttl" ] && DTTL=$(cat "$RESULTS_DIR/$i.ttl")
    case "$DCACHE" in
      hit)      HIT_COUNT=$((HIT_COUNT + 1)); debug_log "  $DLABEL: hit (ttl=${DTTL}, age=${DAGE}) → ${DDUR}ms" ;;
      miss)     MISS_COUNT=$((MISS_COUNT + 1)); debug_log "  $DLABEL: miss (ttl=${DTTL}) → ${DDUR}ms" ;;
      no-cache) NOCACHE_COUNT=$((NOCACHE_COUNT + 1)); debug_log "  $DLABEL: no-cache → ${DDUR}ms" ;;
    esac
  fi
done

DASH_END_MS=$(($(date +%s%N 2>/dev/null || echo "$(date +%s)000000000") / 1000000))
DASH_TOTAL_MS=$((DASH_END_MS - DASH_START_MS))
debug_log "--- dashboard done: ${DASH_TOTAL_MS}ms (${HIT_COUNT} hit, ${MISS_COUNT} miss, ${NOCACHE_COUNT} no-cache) ---"

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
    if [ "$NO_DURATION" != "1" ] && [ -f "$RESULTS_DIR/$i.durms" ]; then
      MS=$(cat "$RESULTS_DIR/$i.durms")
      THRESHOLD_MS=$((DURATION_THRESHOLD * 1000))
      if [ "$MS" -ge "$THRESHOLD_MS" ]; then
        SECS=$(( (MS + 500) / 1000 ))  # round to nearest second
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
