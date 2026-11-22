#!/bin/bash
# Writes bench-wide settings to sites/common_site_config.json.
set -euo pipefail

cd /home/frappe/frappe-bench

ls -1 apps > sites/apps.txt

bench set-config -g db_host "${DB_HOST:-db}"
bench set-config -gp db_port "${DB_PORT:-3306}"
bench set-config -g redis_cache "redis://${REDIS_CACHE:-redis-cache:6379}"
bench set-config -g redis_queue "redis://${REDIS_QUEUE:-redis-queue:6379}"
bench set-config -g redis_socketio "redis://${REDIS_QUEUE:-redis-queue:6379}"
bench set-config -gp socketio_port "${SOCKETIO_PORT:-9000}"

if [[ -x /usr/lib/chromium/chromium-headless-shell ]]; then
  bench set-config -g chromium_path /usr/lib/chromium/chromium-headless-shell
fi

echo "common_site_config.json:"
cat sites/common_site_config.json
