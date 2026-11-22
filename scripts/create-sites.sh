#!/bin/bash
# Creates every site listed in $SITES (comma separated) that does not exist yet,
# installs any missing apps on existing sites and optionally migrates them.
#
# Each site name must equal the domain it is served on, because nginx picks
# the site from the Host header (multi-tenant by domain).
set -euo pipefail

cd /home/frappe/frappe-bench

: "${SITES:?Set SITES to a comma separated list of domains, e.g. erp.example.com,hr.example.com}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD is required}"
: "${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD is required}"

DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}
SITE_PROTOCOL=${SITE_PROTOCOL:-https}
AUTO_MIGRATE=${AUTO_MIGRATE:-true}

wait-for-it -t 180 "$DB_HOST:$DB_PORT"
wait-for-it -t 120 "${REDIS_CACHE:-redis-cache:6379}"
wait-for-it -t 120 "${REDIS_QUEUE:-redis-queue:6379}"

if [[ -n "${INSTALL_APPS:-}" ]]; then
  IFS=',' read -ra APPS <<< "$INSTALL_APPS"
else
  mapfile -t APPS < <(grep -vx frappe sites/apps.txt)
fi

APP_LIST=()
for app in "${APPS[@]}"; do
  app=$(echo "$app" | xargs)
  [[ -n "$app" ]] && APP_LIST+=("$app")
done
echo "Apps to install on each site: ${APP_LIST[*]:-<none>}"

IFS=',' read -ra SITE_LIST <<< "$SITES"
for site in "${SITE_LIST[@]}"; do
  site=$(echo "$site" | xargs | tr '[:upper:]' '[:lower:]')
  [[ -z "$site" ]] && continue

  if [[ ! "$site" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; then
    echo "Invalid site name '$site' (use the domain, e.g. erp.example.com)" >&2
    exit 1
  fi

  if [[ -f "sites/$site/site_config.json" ]]; then
    echo "==> Site $site already exists"
    installed=$(bench --site "$site" list-apps 2>/dev/null | awk '{print $1}')
    for app in "${APP_LIST[@]}"; do
      if ! grep -qx "$app" <<< "$installed"; then
        echo "Installing missing app $app on $site"
        bench --site "$site" install-app "$app"
      fi
    done
    if [[ "$AUTO_MIGRATE" == "true" ]]; then
      echo "Migrating $site"
      bench --site "$site" migrate
    fi
  else
    echo "==> Creating site $site"
    install_args=()
    for app in "${APP_LIST[@]}"; do
      install_args+=(--install-app "$app")
    done
    bench new-site "$site" \
      --mariadb-user-host-login-scope='%' \
      --db-root-username=root \
      --db-root-password="$DB_ROOT_PASSWORD" \
      --admin-password="$ADMIN_PASSWORD" \
      "${install_args[@]}"
  fi

  # Absolute URLs (emails, print links, OAuth) must use the public domain,
  # because the request reaches Frappe over plain HTTP from the proxy.
  bench --site "$site" set-config host_name "$SITE_PROTOCOL://$site"
done

echo "All sites ready:"
ls -1 sites | grep -vE '^(assets|apps\.txt|apps\.json|common_site_config\.json)$' || true
