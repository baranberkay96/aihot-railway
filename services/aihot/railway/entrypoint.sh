#!/usr/bin/env bash
# AIHOT on Railway (community template): one entrypoint for every role of this image.
#
#   entrypoint.sh web        the site (React Router SSR) on $PORT; API-owned paths are proxied to Backend
#   entrypoint.sh backend    API on $PORT plus the worker, both using the /data volume (railway/supervise.mjs)
#   entrypoint.sh predeploy  Backend's pre-deploy step: wait for Postgres, run the migrations, add the
#                            demo sources (upstream's docker-compose `setup` service)
#
# The container starts as root only so the Backend can give its volume (mounted root-owned by Railway)
# to the node user; every role then runs as node (uid 1000).
set -euo pipefail

ROLE="${1:-}"
APP_DIR=/app
SELF="$(readlink -f "$0")"

log() { printf '[railway] %s\n' "$*"; }
warn() { printf '[railway] warning: %s\n' "$*"; }
fail() { printf '[railway] error: %s\n' "$*" >&2; exit 1; }

case "$ROLE" in
  web|backend|predeploy) ;;
  *) fail "usage: entrypoint.sh web|backend|predeploy (got '${ROLE}')" ;;
esac

# ── root: prepare the volume, then drop to node ──────────────────────────────
if [ "$(id -u)" = 0 ]; then
  if [ "$ROLE" = backend ]; then
    data="${AIHOT_DATA_DIR:-/data}"
    mkdir -p "$data"
    # Only files that are not node's yet (a fresh volume, a restore made as root); lost+found stays root's.
    if [ -n "$(find "$data" -xdev -path "$data/lost+found" -prune -o ! -user node -print -quit)" ]; then
      log "giving ${data} to the node user"
      find "$data" -xdev -path "$data/lost+found" -prune -o ! -user node -exec chown node:node {} +
    fi
  fi
  exec setpriv --reuid=node --regid=node --init-groups -- env HOME=/home/node USER=node "$SELF" "$@"
fi

cd "$APP_DIR"
export NODE_ENV="${NODE_ENV:-production}"
if [ -z "${AIHOT_RELEASE:-}" ] && [ -r "$APP_DIR/.railway-release" ]; then
  AIHOT_RELEASE="$(cat "$APP_DIR/.railway-release")"
  export AIHOT_RELEASE
fi

# SITE_URL is the address readers use; every generated link, RSS, share image and MCP host check uses it.
# A reference to a missing public domain leaves "https://", which the app cannot parse: drop it so the
# app falls back to its default, and say why.
check_site_url() {
  if [ -z "${SITE_URL:-}" ]; then
    warn "SITE_URL is empty: links will point to http://localhost:3000. Set it to https://{your-domain}."
  elif ! printf '%s' "$SITE_URL" | grep -Eq '^https?://[^/[:space:]]+/?$'; then
    warn "SITE_URL '${SITE_URL}' is not an origin like https://example.com; ignoring it (links will point to http://localhost:3000)."
    unset SITE_URL
  fi
}

wait_for_postgres() {
  local limit="${TEMPLATE_DB_WAIT_SECONDS:-300}" waited=0
  until pg_isready -q -t 5 -d "$DATABASE_URL"; do
    if [ "$waited" -ge "$limit" ]; then
      fail "Postgres did not accept connections within ${limit}s (check the Postgres service and DATABASE_URL)"
    fi
    log "waiting for Postgres (${waited}s)"
    sleep 5
    waited=$((waited + 5))
  done
}

case "$ROLE" in
  web)
    [ -n "${API_BASE_URL:-}" ] || fail "API_BASE_URL is not set (expected http://{Backend private domain}:3001)"
    check_site_url
    export WEB_HOST="${WEB_HOST:-::}"
    export WEB_PORT="${WEB_PORT:-${PORT:-3000}}"
    log "web ${AIHOT_RELEASE:-} on [${WEB_HOST}]:${WEB_PORT}, API ${API_BASE_URL}, site ${SITE_URL:-(default)}"
    exec node apps/web/server.ts
    ;;

  predeploy)
    [ -n "${DATABASE_URL:-}" ] || fail "DATABASE_URL is not set (reference the Postgres service)"
    wait_for_postgres
    # Upstream's migrations fail fast on a lock held by the running deployment; retry a few times.
    attempt=1
    until node scripts/migrate.ts; do
      if [ "$attempt" -ge 3 ]; then
        fail "migrations failed ${attempt} times; see the error above (upstream docs/deploy.md, section on updates)"
      fi
      warn "migration attempt ${attempt} failed, retrying in 15s"
      attempt=$((attempt + 1))
      sleep 15
    done
    if [ "${TEMPLATE_SEED_SOURCES:-true}" = true ]; then
      # Adds the sources of industry/sources.json that are not there yet; never changes existing ones.
      node scripts/seed.ts
    else
      log "TEMPLATE_SEED_SOURCES is not true: demo sources not added"
    fi
    ;;

  backend)
    [ -n "${DATABASE_URL:-}" ] || fail "DATABASE_URL is not set (reference the Postgres service)"
    admin_password="${ADMIN_PASSWORD:-}"
    if [ "${#admin_password}" -lt 12 ] && [ -z "${FEISHU_LOGIN_APP_ID:-}" ]; then
      fail "ADMIN_PASSWORD must be at least 12 characters (upstream refuses to start without an admin login)"
    fi
    unset admin_password
    check_site_url
    export API_HOST="${API_HOST:-::}"
    export API_PORT="${API_PORT:-${PORT:-3001}}"
    data="${AIHOT_DATA_DIR:-/data}"
    [ -w "$data" ] || fail "${data} is not writable by $(id -un); attach the volume at ${data}"

    # Daily backups (worker job ops.backup, 04:10 China time) go to the Railway Bucket. Upstream builds
    # a virtual-hosted URL from DB_BACKUP_STORE_DOMAIN, which is <bucket>.<endpoint host> for a Bucket.
    if [ "${TEMPLATE_BACKUPS:-true}" != true ]; then
      unset DB_BACKUP_STORE_SECRET_ID DB_BACKUP_STORE_SECRET_KEY DB_BACKUP_STORE_BUCKET DB_BACKUP_STORE_REGION DB_BACKUP_STORE_DOMAIN
      log "backups off (TEMPLATE_BACKUPS=${TEMPLATE_BACKUPS})"
    elif [ -n "${DB_BACKUP_STORE_BUCKET:-}" ] && [ -z "${DB_BACKUP_STORE_DOMAIN:-}" ] && [ -n "${TEMPLATE_BACKUP_ENDPOINT:-}" ]; then
      endpoint_host="${TEMPLATE_BACKUP_ENDPOINT#*://}"
      endpoint_host="${endpoint_host%%/*}"
      export DB_BACKUP_STORE_DOMAIN="${DB_BACKUP_STORE_BUCKET}.${endpoint_host}"
    fi
    if [ -n "${DB_BACKUP_STORE_BUCKET:-}" ] && [ -n "${DB_BACKUP_STORE_SECRET_ID:-}" ] && [ -n "${DB_BACKUP_STORE_REGION:-}" ]; then
      log "daily backups to ${DB_BACKUP_STORE_DOMAIN:-the configured store} (prefixes daily/, weekly/, monthly/)"
    elif [ "${TEMPLATE_BACKUPS:-true}" = true ]; then
      warn "no object store configured: the daily backup job is not scheduled"
    fi

    [ -n "${LLM_API_KEY:-}" ] || warn "LLM_API_KEY is empty: sources are collected, but nothing is scored, written up or selected until you set it"
    [ "${COLLECT_ENABLED:-}" = true ] || warn "COLLECT_ENABLED is not 'true': no source is fetched"
    [ "${MODEL_CALLS_ENABLED:-}" = true ] || warn "MODEL_CALLS_ENABLED is not 'true': no model is called"
    log "backend ${AIHOT_RELEASE:-}: API on [${API_HOST}]:${API_PORT} and the worker, data in ${data}"
    exec node "$APP_DIR/railway/supervise.mjs"
    ;;
esac
