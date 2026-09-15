#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_BIN="$(command -v node || true)"
PM2_BIN="$(command -v pm2 || true)"
MARKER="gtimer-sync-api pm2 reboot"
LOG_FILE="/tmp/gtimer-sync-api-reboot.log"

if [[ -z "$NODE_BIN" || -z "$PM2_BIN" ]]; then
  echo "node and pm2 must both be available on PATH." >&2
  exit 1
fi

NODE_BIN_DIR="$(dirname "$NODE_BIN")"

cd "$APP_DIR"
pm2 startOrReload ecosystem.config.cjs --env production
pm2 save

CRON_LINE="@reboot cd \"$APP_DIR\" && PATH=\"$NODE_BIN_DIR:\\$PATH\" \"$PM2_BIN\" resurrect >\"$LOG_FILE\" 2>&1 || (cd \"$APP_DIR\" && PATH=\"$NODE_BIN_DIR:\\$PATH\" \"$PM2_BIN\" start ecosystem.config.cjs --env production >>\"$LOG_FILE\" 2>&1) # $MARKER"
TMP_CRON="$(mktemp)"

crontab -l 2>/dev/null | grep -v "$MARKER" > "$TMP_CRON" || true
printf "%s\n" "$CRON_LINE" >> "$TMP_CRON"
crontab "$TMP_CRON"
rm -f "$TMP_CRON"

echo "Installed user crontab reboot fallback for gtimer-sync-api."
echo "Current PM2 process list was saved with pm2 save."
echo "Reboot log path: $LOG_FILE"
