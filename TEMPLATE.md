# AIHOT 2026.11 AI Hot Topics Site with Daily Reports — Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **AIHOT 2026.11 AI Hot Topics Site with Daily Reports** (`2026.11` = the pinned upstream snapshot; AIHOT has no releases or tags) |
| Description | Self-hosted AI news site: LLM-scored picks, trending events, daily reports (74 chars) |
| Category | AI/ML |
| Tags | aihot, ai-news, news-aggregator, hot-topics, daily-digest, llm, rss, mcp, self-hosted |
| Icon | `https://cdn.jsdelivr.net/npm/lucide-static@1.59.0/icons/flame.svg` (HTTP 200, image/svg+xml, 2026-11-07). Neutral Lucide icon: upstream's NOTICE says the AIHOT logo is not licensed. |
| User input at deploy | **`LLM_API_KEY`** on Backend (any OpenAI-compatible service; DeepSeek is the default base URL and model). Everything else is generated or has a default. |
| Repo for built services | `baranberkay96/aihot-railway` (`/services/gateway`, `/services/aihot` for both Web and Backend) |
| Language | The UI and all generated text (titles, summaries, reports, translations) are **Simplified Chinese**. Upstream has no setting for it: the prompts in `industry/prompts/` and the UI text in `site/site.ts` and the code would have to be translated in a fork. README says so in its second paragraph. |

**Listing wording check.** "LLM-scored picks": every item is pre-screened and scored twice by the model against a tier threshold. "Trending events": heat per event from independent sources over 48 h. "Daily reports": composed by rule at 08:00 China time from the day's selected events (no model call); weekly and monthly reports use the model only for the overview. All three work with the default stack and one model key.

## Base market template

| Code | Name | Stats (2026-11-07) | Verdict |
|---|---|---|---|
| `aihot-engine-ai-news-hot-topics-site` | "AIHOT engine (AI news hot-topics site)" (`localhavenstore/railway-aihot`, MIT) | 2 projects, 0 active | **Read, not used as the base.** One container runs web + API + worker with a `wait -n` script, Postgres 18, upstream commit `2b80294` (2026-10-06). Kept ideas: root → `node` volume handoff with `setpriv`, `SITE_URL` from the Railway domain. Fixed: see "Improvements". |

## Pinned versions

| Component | Source | Version | Date | Checked |
|---|---|---|---|---|
| AIHOT | `KKKKhazix/AIHOT` main at `0ce2d00fd80be416d78d675df732d5e1bef53b40`, codeload tarball, SHA-256 `11432e325631db783808382d3973c926d6906ed38c2863024cd0d8ae23f08faf` | snapshot 2026.11 (no releases, no tags) | committed 2026-11-07 10:41 UTC | 2026-11-07: `gh api` (HEAD of main), tarball downloaded twice with the same hash, extracted tree identical to the local reference copy |
| Node base | `node:24.22.2-trixie-slim@sha256:0820eaa85e07d0490446dd01d14707e17e6108a36988cf374899cd057eb3812d` (upstream uses `node:24-trixie-slim`; `engines` needs ≥ 24.22.1) | 24.22.2 | 2026-11-05 | registry index digest, amd64 present |
| PostgreSQL client | Debian trixie `postgresql-client` (17), as upstream's Dockerfile | 17.x | Debian archive | build asserts `pg_dump` 17 |
| Gateway | `caddy:2.11.9-alpine@sha256:0bbb055bda6793c999bde78b1b5ce3e89f829fb031af2cf50056ea1246559fee` | 2.11.9 | 2026-11-05 (security fixes, mostly FastCGI) | registry index digest |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` (index `sha256:5e806d28…3463e`) | PostgreSQL 17.11 | image built 2026-10-23 | GHCR manifest and config |

**Why Postgres 17, not the base 18:** upstream supports PostgreSQL 16 or 17 (`docs/deploy.md`), its CI and compose run 17, and its Dockerfile installs Debian's client 17 for the backups. `pg_dump` 17 refuses to dump an 18 server, so the market template's Postgres 18 would make every configured backup fail. The base service definition (variables, volume path, `PGDATA`) is copied from `_railway-base/postgres.json` with only the tag changed.

## Architecture

```
Internet --HTTPS--> Gateway (Caddy :8080, only public domain)
                      | encode zstd/gzip, security headers, X-Forwarded-For = real client
                      v
                    Web (Node :3000, React Router SSR, stateless)
                      | pages: SSR loaders read the API over HTTP
                      | API-owned paths (/api/*, /feed*.xml, /sitemap*, /robots.txt, /og/*, /.well-known/*, /api/mcp ...)
                      v   proxied as-is (Host and X-Forwarded-Proto kept)
                    Backend (railway/supervise.mjs, volume /data)
                      |- api     Fastify :3001  site API, public API v1, RSS, MCP, admin API, image proxy, share images
                      '- worker  pg-boss queues + schedules (Asia/Shanghai): collect, model steps, grouping, heat, reports, backups
                      |      pre-deploy: wait for Postgres -> scripts/migrate.ts -> scripts/seed.ts
                      v
                    Postgres 17 (volume)          Backups (Railway Bucket) <- daily pg_dump + uploads
```

### Deviations from upstream `docker-compose.yml` and why

- **api and worker share one service.** Compose mounts one `data` volume into both. The worker writes into it what the API serves: resized renditions, AVIF variants and converted GIFs (`media.prepare`, `media/images.ts`), pre-rendered share images (`warmShareImage`, "shared disk cache"); it packs the API's `uploads/` and `feedback-screenshots/` into backups and prunes the API's `imgcache/`/`ogcache/` monthly (`operations/retention.ts`). A Railway volume belongs to one service (Rule 3b), so split services would leave the API's image cache unpruned (it would grow until the volume is full), make every AVIF/GIF job run against the wrong disk, and back up no uploads. `railway/supervise.mjs` runs both processes: a crashed one restarts alone with backoff (1 s → 60 s), ten quick failures in a row exit the container, and SIGTERM stops the worker first so the API keeps answering while the worker drains.
- **setup → Backend pre-deploy.** Same commands (`scripts/migrate.ts && scripts/seed.ts`), after a `pg_isready` wait (≤ 300 s) and with up to 3 migration attempts 15 s apart (upstream migrations use a 1 s lock timeout and the old deployment is still running during pre-deploy). `preDeployTimeoutSeconds` 900 covers the DB wait plus upstream's wait for a running backup `pg_dump` (≤ 470 s). Rule 8.6.
- **Caddy is always on** as the Gateway (upstream: optional `https` profile). Railway's edge terminates TLS; Caddy keeps upstream's compression and security headers and adds Railway's trusted-proxy handling so `TRUST_PROXY=true` on Web sees real visitor IPs (sign-in throttling and feedback limits are per IP).
- **Web listens on `::`, API on `::`** (Node dual-stack; compose uses 0.0.0.0). Rule 8.14.
- **Backups wired to a Railway Bucket.** Upstream backs up to any S3-compatible store when `DB_BACKUP_STORE_*` are set. The entrypoint derives `DB_BACKUP_STORE_DOMAIN` = `{bucket}.{endpoint host}` (virtual-hosted style, which upstream's SigV4 client uses and Railway Buckets require).
- **Run as `node`.** The image starts as root only to `chown` files on `/data` that are not `node`'s yet (skipping `lost+found`), then `setpriv` drops to uid 1000 for every role.
- **No template patches to upstream code.** The site is upstream's code byte for byte.

## Security model

- **One public domain: Gateway.** Web, Backend and Postgres have no domain and no TCP proxy. Web receives only `SITE_URL`, `API_BASE_URL`, `TRUST_PROXY` (upstream design: secrets and the volume stay in the backend).
- **Public by design:** pages, public API v1, RSS, `llms.txt`, MCP (read-only tools), the feedback form (rate-limited per IP).
- **Admin** (`/admin`, `/api/admin/*`): upstream password login with `ADMIN_PASSWORD` (generated, 32 chars from a 56-character alphabet), sessions signed with `SESSION_SECRET` and bound to the login method, CSRF token on admin writes, Secure cookie because `X-Forwarded-Proto: https` passes from Railway's edge through the trusted Gateway. The API refuses to start in production without a ≥ 12-character password; the entrypoint checks it first with a clear message.
- **Push API** `/api/ingest/items`: off unless `INGEST_TOKEN` (≥ 16 chars) is set; then token plus `INGEST_RATE_LIMIT` (10/min).
- **Image proxy** only fetches URLs signed with `IMG_PROXY_SIGN_SECRET`; upstream refuses private-network fetches (production refuses to start with `ALLOW_PRIVATE_NETWORK_FETCH`).
- **Spending valves:** `COLLECT_ENABLED`, `MODEL_CALLS_ENABLED` (only `true` enables), per-service budgets in admin settings for paid collectors.
- **Supply chain:** source tarball SHA-256 checked before `npm ci`; `npm ci` follows upstream's lockfile; base images by digest. A fork build without `AIHOT_SOURCE_SHA256` prints a warning and the hash.

## Services

5 resources: 3 repo services, Postgres, 1 bucket.

### Gateway

| Setting | Value |
|---|---|
| Source | repo `/services/gateway` (`FROM caddy:2.11.9-alpine@…`, Caddyfile validated at build) |
| Public domain | **yes**, target port 8080 |
| Healthcheck | `/gateway-health`, 120 s |
| Restart | ON_FAILURE ×10 |
| Variables | `PORT=8080`, `AIHOT_WEB_UPSTREAM=${{Web.RAILWAY_PRIVATE_DOMAIN}}:${{Web.PORT}}` |

### Web

| Setting | Value |
|---|---|
| Source | repo `/services/aihot` (pinned AIHOT build), start `/app/railway/entrypoint.sh web` |
| Healthcheck | `/terms`, 300 s: a static page whose root loader tolerates an unreachable API, so Web is healthy on its own (the home page needs the API and the database) |
| Restart | ALWAYS |
| Variables | `PORT=3000` (→ `WEB_PORT`, `WEB_HOST=::`), `API_BASE_URL=http://${{Backend.RAILWAY_PRIVATE_DOMAIN}}:${{Backend.PORT}}`, `SITE_URL=https://${{Gateway.RAILWAY_PUBLIC_DOMAIN}}`, `TRUST_PROXY=true`, `AIHOT_SOURCE_REPO/COMMIT/SHA256` = Backend's |

### Backend

| Setting | Value |
|---|---|
| Source | repo `/services/aihot` (same image), start `/app/railway/entrypoint.sh backend` |
| Pre-deploy | `/app/railway/entrypoint.sh predeploy` (timeout 900 s) |
| Healthcheck | `/api/health` (runs `SELECT 1`), 600 s, `PORT=3001` (→ `API_PORT`, `API_HOST=::`) |
| Volume | `/data` (`AIHOT_DATA_DIR`): uploads, feedback screenshots, image and share-image caches (pruned after 30 days), sitemap cache, last 3 local backups |
| Restart | ALWAYS; `RAILWAY_DEPLOYMENT_DRAINING_SECONDS=300` |
| Required input | `LLM_API_KEY` |
| Generated | `ADMIN_PASSWORD` (`secret(32, 56 chars)`), `SESSION_SECRET`, `IMG_PROXY_SIGN_SECRET` (`secret(64, hex)`) |
| Model | `LLM_BASE_URL=https://api.deepseek.com/v1`, `LLM_MODEL=deepseek-flash`, `LLM_EXTRA_JSON={"thinking":{"type":"disabled"}}` (upstream `init-env` defaults), `LLM_REASONING_TOKENS`, `LLM_VISION=false` |
| Optional | `EMBEDDING_BASE_URL/API_KEY/MODEL`, `INGEST_TOKEN`, `SOCIALDATA_API_KEY`, `JINA_API_KEY`, `GITHUB_TOKEN`; any other upstream variable from `.env.example` (Feishu, DingTalk, `EGRESS_PROXY_URL`, per-step `*_MODEL` …) can be added |
| Wiring | `DATABASE_URL=${{Postgres.DATABASE_URL}}`, `SITE_URL=${{Web.SITE_URL}}`, `COLLECT_ENABLED=true`, `MODEL_CALLS_ENABLED=true`, `INGEST_RATE_LIMIT=10`, `DB_BACKUP_STORE_SECRET_ID/SECRET_KEY/BUCKET/REGION` and `TEMPLATE_BACKUP_ENDPOINT` from the Backups bucket |
| Template switches | `TEMPLATE_BACKUPS=true`, `TEMPLATE_BACKUP_ON_BOOT=false`, `TEMPLATE_SEED_SOURCES=true`, `TEMPLATE_DB_WAIT_SECONDS` (not set, 300), `AIHOT_SOURCE_REPO/COMMIT/SHA256` (empty = pinned snapshot) |

### Postgres

`ghcr.io/railwayapp-templates/postgres-ssl:17`, base variables (`POSTGRES_PASSWORD` letters only), volume `/var/lib/postgresql/data`, ON_FAILURE ×10, no TCP proxy. Migrations create `pg_trgm` (contrib, available in the image). No pgvector needed: embeddings are stored as `real[]` and recall scans a bounded window.

### Backups (Railway Bucket)

Holds `daily/`, `weekly/` (Sundays), `monthly/` (1st) objects `railway-YYYYMMDDHHMM.dump` (+ `railway-files-….tar.gz` when uploads exist). No expiry rule; old objects are deleted by hand.

## Schedules and the first daily report

The worker schedules in `Asia/Shanghai` (fixed upstream): sources due every minute (interval adapts per source), content sweep/translation/heat every 5 min, alerts and recovery every 10 min, `reports.compose` at :00 and :30, retention 03:30, backup 04:10, icons 04:40.

- **First import:** each source's first fetch keeps up to 30 recent items and marks them `first-import` backfill (archived by publish date, never in "today", reports or pushes). Upstream measured 152 items and ~930 model calls for the demo sources, about 30 min.
- **First daily report:** `composeDueReports` starts at the newest due day when no report exists. The daily for day D covers [D−1 08:00, D 08:00) China time and fails with "nothing judged in its window" when no non-backfill item in that window has a score. So the first report is written at 08:00/08:30 China time (00:00/00:30 UTC) of the first morning whose previous 24 h contain scored items collected after the first import — normally the first morning after the deploy, the second if the deploy was shortly before 08:00. Until then the failure shows on the admin Runs page; earlier days are never back-filled.
- Weekly (Monday 10:00) and monthly (1st, 10:30) reports start with the first period that contains a daily.

## Improvements over market templates

1. **Current code:** snapshot `0ce2d00` (2026-11-07) vs `2b80294` (2026-10-06): 153 commits newer, 17 more migrations (0083–0126), DingTalk pushes, report, alert and feedback fixes. Source checked by SHA-256 (market: `git clone` + checkout, no checksum).
2. **Correct variable descriptions** (the market's are shifted by one: `DATABASE_URL` is described as the admin login, `ADMIN_PASSWORD` as the session secret, `IMG_PROXY_SIGN_SECRET` as the drain time) and `LLM_API_KEY` is a real required input (market: optional with "REQUIRED" in the text).
3. **Separate services** with their own healthchecks: stateless Web (replicable), Backend, Gateway. Market: one container where any of three processes exiting restarts all three.
4. **Worker drains without taking the site down:** supervisor stops the worker first and keeps the API up; a crashed process restarts alone.
5. **Migrations in pre-deploy** with a DB wait and lock retries (market: in the start script on every boot).
6. **Postgres 17** matching upstream and its `pg_dump` (market: 18, which would break backups).
7. **Daily backups to a Railway Bucket** out of the box, plus `backup-now.ts` / `TEMPLATE_BACKUP_ON_BOOT` to test them (market: none).
8. **Gateway with upstream's compression and security headers** and correct client IPs.
9. **Fork builds** (`AIHOT_SOURCE_*`): the supported way to change name, language, prompts, thresholds and report times, which upstream keeps in code.
10. **Exposed valves and options:** `COLLECT_ENABLED`, `MODEL_CALLS_ENABLED`, `LLM_EXTRA_JSON`, `LLM_REASONING_TOKENS`, embeddings, paid collectors, ingest token.
11. **Honest README:** Chinese UI and output, when the first daily appears, costs.

## Scaling

- **Backend:** one replica (volume, schedules). Scale vertically; AVIF encodes and share-image renders are the memory peaks. `DATABASE_POOL_MAX` (default 10 per process) can be raised with Postgres `max_connections` in mind.
- **Web, Gateway:** stateless; `numReplicas` can be raised.
- **Throughput and cost** scale with new items per day; per-step models (`PREFILTER_MODEL`, `SCORE_MODEL`, … or the admin Models page) and source intervals are the levers (upstream `docs/deploy.md`, cost section).

## Resource estimate

Prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month. **Not measured** (no container was run); based on Node footprints of comparable apps and upstream's notes.

| Service | Idle RAM | Typical RAM | Idle vCPU | Typical vCPU | Volume |
|---|---|---|---|---|---|
| Gateway | 20 MB | 40 MB | 0.002 | 0.02 | — |
| Web | 120 MB | 200 MB | 0.005 | 0.05 | — |
| Backend (api + worker) | 350 MB | 700 MB (bursts ~1.2 GB) | 0.03 | 0.25 | 0.3–3 GB |
| Postgres | 80 MB | 200 MB | 0.005 | 0.05 | 0.2–2 GB |
| Backups bucket | — | — | — | — | grows by one dump a day |

- **Idle ≈ $7/month** (≈ 0.57 GB RAM, ≈ 0.04 vCPU, ≈ 0.5 GB volumes).
- **Typical ≈ $15–20/month** (≈ 1.1 GB RAM, ≈ 0.35 vCPU, ≈ 3 GB volumes, small egress) with the demo sources and modest traffic.
- **Minimum plan: Hobby.** Trial's 1 GB per service is tight for Backend during image work. Model calls are billed by the provider (not included).

## Upgrade path

Set `AIHOT_SOURCE_COMMIT` (and `AIHOT_SOURCE_SHA256` from the build log or `curl -L https://codeload.github.com/KKKKhazix/AIHOT/tar.gz/{sha} | sha256sum`) on Backend, back up first (`TEMPLATE_BACKUP_ON_BOOT=true`), then deploy Backend and Web. Or bump `pinned_commit`/`pinned_sha256` in `services/aihot/Dockerfile` here and update the listing name's snapshot label. Read upstream's `docs/deploy.md` update notes for each sync: upstream asks to stop api/worker before destructive migrations; on Railway the old Backend keeps running during pre-deploy, so for a release with destructive migrations set `MODEL_CALLS_ENABLED=false` and `COLLECT_ENABLED=false` first or accept a few failed jobs that recover. Re-check `docker-compose.yml`, `Dockerfile` and `.env.example` for new roles or variables.

## Verification checklist

1. Builds: Gateway (Caddyfile validated), Web and Backend logs show `source KKKKhazix/AIHOT@0ce2d00… verified (sha256 11432e32…)` and `KKKKhazix/AIHOT@0ce2d00fd80b`.
2. Backend pre-deploy log: `74 migration(s) applied` on a fresh database (then `database is up to date`) and `sources: 18 added, 0 already there`.
3. `https://{domain}/gateway-health` → 200 `ok`; `https://{domain}/api/health` → `{"ok":true,"db":"ok",…,"release":"KKKKhazix/AIHOT@0ce2d00fd80b"}`.
4. Upstream smoke check from the Backend or Web shell: `node scripts/smoke.ts --base https://{domain}` → `all checks passed` (15 pages, 14 machine endpoints, MCP initialize with server name `myhot`).
5. Admin: `/admin` without a cookie → 302 to `/api/auth/login`; POST `/api/auth/password` (form `password={ADMIN_PASSWORD}`) → 303 with a `Secure` `Set-Cookie`; a wrong password → back to the login page.
6. Response headers through the Gateway: `content-encoding: zstd` or `gzip` on HTML with `Accept-Encoding`, `strict-transport-security`, `x-frame-options: SAMEORIGIN`.
7. Worker: within minutes admin → Sources shows fetches for the 18 feeds; with a valid key, admin → Models shows calls and the home page fills within ~30–60 min. Without a key the Backend log warns and items wait.
8. Backups (Rule 8.25): set `TEMPLATE_BACKUP_ON_BOOT=true`, redeploy Backend → log `backup-now: uploaded` with `daily/railway-….dump` (or `weekly/`/`monthly/`); the object is in the Backups bucket; set the switch back.
9. Persistence: redeploy Backend → items, sources and the admin session survive; Backend log shows `stopping the worker first, then the API` and `stopped`.
10. First daily report at the next 00:00/00:30 UTC: `/daily` shows it, admin Runs shows `reports.compose` OK.

## Open questions

- **Builds not run here** (no Docker by instruction): `npm ci` + React Router build on Railway's builder (upstream recommends ≥ 4 GB RAM for the build), `caddy validate` at build, `setpriv` in Railway's pre-deploy container.
- **Railway Bucket with upstream's SigV4 PUT:** virtual-hosted domain derived from `ENDPOINT`, region as given by the bucket (e.g. `auto`), `x-amz-content-sha256` with the real payload hash. Expected to work; only checklist item 8 proves it.
- **`RAILWAY_DEPLOYMENT_DRAINING_SECONDS=300`:** whether the old Backend's API still receives private traffic while draining (if not, the site shows API errors for the drain time on a Backend redeploy, as any volume service would).
- **Codeload tarball stability:** GitHub generates archives on demand; their checksums have been stable since 2023 but are not contractually fixed. A mismatch fails the build with both hashes printed.
- **Default model id** `deepseek-flash` is upstream's current default (`.env.example`, `site/models.ts`); not called here.
- **Client IP chain** Railway edge → Caddy (`trusted_proxies private_ranges 100.64.0.0/10`) → Web is the pattern deploy-tested in World Monitor (round 4), not yet with AIHOT's limits.
