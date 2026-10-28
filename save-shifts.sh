#!/bin/bash
set -euo pipefail
DEST="$HOME/.config/omarchy/shifts.json"
DATA="${1:-}"
if [ -z "$DATA" ]; then
  DATA="{}"
fi

mkdir -p "$(dirname "$DEST")"
TMP="$(mktemp "${DEST}.tmp.XXXXXX")"
printf '%s\n' "$DATA" > "$TMP"
mv -f "$TMP" "$DEST"
