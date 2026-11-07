# AIHOT for Railway (community template).
#
# AIHOT publishes no container image, so this builds upstream's own Dockerfile
# steps from a pinned commit: the source is the codeload tarball of that commit,
# checked against a SHA-256 before anything runs. One image serves three roles
# (railway/entrypoint.sh):
#   Web       entrypoint.sh web        React Router SSR site, proxies API paths to Backend
#   Backend   entrypoint.sh backend    API + worker on the shared /data volume
#   (Backend pre-deploy) entrypoint.sh predeploy   migrations + demo sources
#
# Build your own fork instead (that is how AIHOT is meant to be customised):
# set AIHOT_SOURCE_REPO (owner/name, public), AIHOT_SOURCE_COMMIT (full 40-char
# SHA) and optionally AIHOT_SOURCE_SHA256 on the Backend service; Web references
# them. Railway passes service variables to the build as build args. Empty
# values (or an unresolved ${{...}} reference) mean the pinned snapshot below.

ARG NODE_IMAGE=node:24.22.2-trixie-slim@sha256:0820eaa85e07d0490446dd01d14707e17e6108a36988cf374899cd057eb3812d

# ── Stage 1: pinned, checksum-verified source ───────────────────────────────
# After extraction the tree is trimmed like upstream's .dockerignore (no .git,
# .github, node_modules, build output, .env files or logs).
FROM ${NODE_IMAGE} AS source
ARG AIHOT_SOURCE_REPO
ARG AIHOT_SOURCE_COMMIT
ARG AIHOT_SOURCE_SHA256
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
RUN set -eu; \
    pinned_repo="KKKKhazix/AIHOT"; \
    pinned_commit="0ce2d00fd80be416d78d675df732d5e1bef53b40"; \
    pinned_sha256="11432e325631db783808382d3973c926d6906ed38c2863024cd0d8ae23f08faf"; \
    unresolved() { case "$1" in *'${{'*) return 0 ;; *) return 1 ;; esac; }; \
    repo="${AIHOT_SOURCE_REPO:-}"; commit="${AIHOT_SOURCE_COMMIT:-}"; sha="${AIHOT_SOURCE_SHA256:-}"; \
    if unresolved "$repo"; then repo=""; fi; \
    if unresolved "$commit"; then commit=""; fi; \
    if unresolved "$sha"; then sha=""; fi; \
    repo="${repo:-$pinned_repo}"; \
    commit="${commit:-$pinned_commit}"; \
    if ! printf '%s' "$repo" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then \
      echo "AIHOT_SOURCE_REPO must look like owner/name, got '$repo'" >&2; exit 1; fi; \
    if ! printf '%s' "$commit" | grep -Eq '^[0-9a-f]{40}$'; then \
      echo "AIHOT_SOURCE_COMMIT must be a full 40-character commit SHA (branches and tags move), got '$commit'" >&2; exit 1; fi; \
    if [ -z "$sha" ] && [ "$repo" = "$pinned_repo" ] && [ "$commit" = "$pinned_commit" ]; then sha="$pinned_sha256"; fi; \
    curl --retry 5 --retry-all-errors --retry-delay 5 --connect-timeout 30 -fsSL \
      -o /tmp/aihot.tar.gz "https://codeload.github.com/${repo}/tar.gz/${commit}"; \
    actual="$(sha256sum /tmp/aihot.tar.gz | cut -d ' ' -f 1)"; \
    if [ -n "$sha" ]; then \
      if [ "$actual" != "$sha" ]; then \
        echo "checksum mismatch for ${repo}@${commit}: expected ${sha}, got ${actual}" >&2; exit 1; fi; \
      echo "source ${repo}@${commit} verified (sha256 ${actual})"; \
    else \
      echo "WARNING: AIHOT_SOURCE_SHA256 is empty, ${repo}@${commit} is not verified; its tarball sha256 is ${actual}"; \
    fi; \
    mkdir /src; \
    tar -xzf /tmp/aihot.tar.gz -C /src --strip-components=1; \
    rm -f /tmp/aihot.tar.gz; \
    cd /src; \
    for f in package.json package-lock.json apps/api/src/main.ts apps/worker/src/main.ts apps/web/server.ts scripts/migrate.ts scripts/seed.ts packages/backend/src/operations/backup.ts; do \
      [ -f "$f" ] || { echo "${repo}@${commit} has no $f: not an AIHOT tree this template can run" >&2; exit 1; }; \
    done; \
    rm -rf .git .github node_modules apps/web/node_modules apps/web/build apps/web/.react-router .data; \
    find . -maxdepth 1 -name '.env*' ! -name .env.example -exec rm -rf {} +; \
    find . -name '*.log' -type f -delete; \
    printf '%s@%.12s\n' "$repo" "$commit" > /src/.railway-release

# ── Stage 2: runtime base (upstream Dockerfile `base`) ──────────────────────
FROM ${NODE_IMAGE} AS base
WORKDIR /app
# pg_dump/pg_restore for the daily backups and pg_isready for the pre-deploy
# wait. Debian trixie's client is PostgreSQL 17, the same major as the
# template's Postgres service (pg_dump refuses newer servers).
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-client ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && pg_dump --version | grep -q ' 17\.' \
 && pg_isready --version \
 && command -v setpriv

# ── Stage 3: build (upstream Dockerfile `build`) ────────────────────────────
FROM base AS build
ARG NPM_REGISTRY=
COPY --from=source /src/ /app/
RUN npm ci --no-audit --no-fund --fetch-retries=5 --fetch-retry-maxtimeout=120000 ${NPM_REGISTRY:+--registry=$NPM_REGISTRY}
RUN npm run build -w @aihot/web \
 && npm prune --omit=dev --no-audit --no-fund \
 && test -f apps/web/build/server/index.js

# ── Stage 4: runtime ────────────────────────────────────────────────────────
FROM base
ENV NODE_ENV=production \
    AIHOT_DATA_DIR=/data \
    MALLOC_ARENA_MAX=2
COPY --from=build --chown=node:node /app /app
COPY --chmod=0755 railway/ /app/railway/
RUN mkdir -p /data \
 && chown node:node /data \
 && bash -n /app/railway/entrypoint.sh \
 && node --check /app/railway/supervise.mjs \
 && cat /app/.railway-release
EXPOSE 3000 3001
# Starts as root only so the Backend can hand its volume to the node user;
# entrypoint.sh drops to node (uid 1000) before any app code runs.
CMD ["/app/railway/entrypoint.sh", "web"]
