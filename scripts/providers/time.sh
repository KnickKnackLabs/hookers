#!/usr/bin/env bash
# Dashboard provider: current date/time
# Usage: time.sh [format] [timezone]
#   Formats:
#     time     — 14:23 EST
#     date     — 2026-03-21
#     day      — Sunday
#     datetime — 2026-03-21 14:23 EST (default)
#     unix     — 1742605380
#   Timezone: IANA zone (e.g. America/New_York). Defaults to UTC.

FORMAT="${1:-datetime}"
TZ="${2:-UTC}"
export TZ

case "$FORMAT" in
  time)     date "+%H:%M %Z" ;;
  date)     date "+%Y-%m-%d" ;;
  day)      date "+%A" ;;
  datetime) date "+%Y-%m-%d %H:%M %Z" ;;
  unix)     date -u "+%s" ;;
  *)
    echo "unknown format: $FORMAT" >&2
    exit 1
    ;;
esac
