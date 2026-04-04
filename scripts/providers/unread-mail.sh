#!/usr/bin/env bash
# Dashboard provider: unread email count
set -euo pipefail
emails list -n 200 2>/dev/null | grep ' \*' | wc -l | tr -d ' '
