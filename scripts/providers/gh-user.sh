#!/usr/bin/env bash
# Dashboard provider: authenticated GitHub username
set -euo pipefail
gh api /user --jq '.login' 2>/dev/null
