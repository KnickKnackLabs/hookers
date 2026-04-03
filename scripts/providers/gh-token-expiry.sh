#!/usr/bin/env bash
# Dashboard provider: GitHub token days until expiry
set -euo pipefail
EXPIRY=$(gh api /user -i 2>/dev/null | grep -i github-authentication-token-expiration | sed 's/.*: //' | tr -d '\r')
[ -z "$EXPIRY" ] && exit 0

# Cross-platform epoch conversion (macOS vs Linux)
EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S UTC" "$EXPIRY" "+%s" 2>/dev/null || date -d "$EXPIRY" "+%s" 2>/dev/null)
NOW=$(date "+%s")
echo "$(( (EPOCH - NOW) / 86400 ))d"
