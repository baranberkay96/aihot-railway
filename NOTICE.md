# Notice

This is a community Railway template for AIHOT. It is not made, endorsed or supported by the AIHOT author.

## Upstream software

| Component | Source | License |
|---|---|---|
| AIHOT (web, API, worker, migrations, demo sources, prompts) | [KKKKhazix/AIHOT](https://github.com/KKKKhazix/AIHOT), commit `0ce2d00fd80be416d78d675df732d5e1bef53b40` (main, 2026-11-07), downloaded at build time from `https://codeload.github.com/KKKKhazix/AIHOT/tar.gz/0ce2d00fd80be416d78d675df732d5e1bef53b40` and checked against SHA-256 `11432e325631db783808382d3973c926d6906ed38c2863024cd0d8ae23f08faf`; built unmodified | MIT, Copyright (c) 2026 数字生命卡兹克 |
| Noto Sans SC (share-image font, inside the AIHOT tree, `assets/og-fonts/`) | Same commit | SIL Open Font License 1.1 |
| npm dependencies of AIHOT | Installed by `npm ci` from upstream's `package-lock.json` at build time | their own licenses (MIT, Apache-2.0, ISC, BSD and others) |
| Node.js base image | `node:24.22.2-trixie-slim` (Docker official image), by digest | MIT (Node.js); Debian packages under their own licenses |
| PostgreSQL client (`pg_dump`, `pg_restore`, `pg_isready`) | Debian trixie package `postgresql-client` (PostgreSQL 17) | PostgreSQL License |
| Caddy | `caddy:2.11.9-alpine` (Docker official image), by digest | Apache-2.0 |
| PostgreSQL server | `ghcr.io/railwayapp-templates/postgres-ssl:17` (Railway's Postgres image) | PostgreSQL License |
| Icons | [Lucide](https://lucide.dev) `flame`, `newspaper`, `server-cog` via `lucide-static@1.59.0` on jsDelivr, referenced by URL | ISC |

This repository does not contain AIHOT's source code; the build downloads it from the URL above.

**Name and logo.** Upstream's NOTICE states that the name "AIHOT" and the AIHOT logo are not licensed under the MIT License and asks every site to use its own name and logo. The template uses the name only to say which software it deploys, uses no AIHOT logo (the icons are Lucide's), and the deployed site keeps upstream's default name, MyHOT, until you change it in your fork.

**Demo sources.** `industry/sources.json` lists public feeds of their publishers (OpenAI, Google DeepMind, The Verge and others). Their content belongs to them; by default the site shows a summary and a link to the original. Whoever runs a site is responsible for the sources they add and the content they republish.

## Adapted from upstream (MIT)

- `services/aihot/Dockerfile`: the `base`, `build` and runtime stages follow upstream's `Dockerfile` (Node 24 trixie-slim, `postgresql-client`, `npm ci`, `npm run build -w @aihot/web`, `npm prune --omit=dev`, files owned by `node`). The source stage, checksum check and fork variables are ours.
- `services/gateway/Caddyfile`: compression (`encode zstd gzip`) and the five `?`-prefixed security headers come from upstream's `deploy/Caddyfile`. The listener, health route, trusted-proxy and client-IP handling are ours.
- `services/aihot/railway/entrypoint.sh`: the pre-deploy role runs upstream's `scripts/migrate.ts` and `scripts/seed.ts`, the commands of the `setup` service in upstream's `docker-compose.yml`.
- `services/aihot/railway/backup-now.ts` calls upstream's `runBackup()` from `packages/backend/src/operations/backup.ts`.

## Market template read for ideas (MIT)

The Railway template "AIHOT engine (AI news hot-topics site)" and its repository [localhavenstore/railway-aihot](https://github.com/localhavenstore/railway-aihot) (MIT, Copyright (c) 2026 Localhaven) were read. Ideas used: starting as root only to give the root-owned Railway volume to the `node` user and then dropping privileges with `setpriv`, and taking `SITE_URL` from the Railway domain. No file was copied; the scripts here are written for this template and differ in structure (separate Web and Gateway services, a supervisor that restarts one process without the other and stops the worker before the API, pre-deploy migrations, Bucket backups).

## Written for this template

`TEMPLATE.md`, `template.json`, `README.md`, this file, `services/aihot/railway/entrypoint.sh`, `services/aihot/railway/supervise.mjs`, `services/aihot/railway/backup-now.ts`, `services/gateway/Dockerfile`, and the parts of `services/aihot/Dockerfile` and `services/gateway/Caddyfile` named above. They are offered under the MIT License below.

## Verified against

Upstream at commit `0ce2d00fd80b` (the tarball matched the local reference copy file for file), checked 2026-11-07: `README.md`, `README.en.md`, `NOTICE`, `LICENSE`, `SECURITY.md`, `Dockerfile`, `.dockerignore`, `docker-compose.yml`, `deploy/Caddyfile`, `.env.example`, `package.json`, `docs/deploy.md`, `docs/architecture.md`, `.github/workflows/check.yml`, `scripts/migrate.ts`, `scripts/seed.ts`, `scripts/smoke.ts`, `apps/api/src/main.ts`, `apps/api/src/app.ts`, `apps/api/src/routes/admin-auth.ts`, `apps/api/src/routes/media.ts`, `apps/worker/src/main.ts`, `apps/worker/src/schedules.ts`, `apps/web/server.ts`, `apps/web/app/root.tsx`, `apps/web/app/routes.ts`, `apps/web/app/lib/api-proxy.server.ts`, `packages/contracts/src/http-policy.ts`, `packages/backend/src/config.ts`, `db.ts`, `jobs/queue.ts`, `jobs/notify.ts`, `media/images.ts`, `media/og.ts`, `media/prepare.ts`, `admin/settings.ts`, `operations/backup.ts`, `providers/llm.ts`, `content/materials.ts`, `sources/collect.ts`, `reports/compose.ts`, `reports/edition.ts`, `site/site.ts`, `site/models.ts`, `industry/sources.json`, `database/migrations/` (extensions).

## MIT License

The MIT License applies to AIHOT (Copyright (c) 2026 数字生命卡兹克), to localhavenstore/railway-aihot (Copyright (c) 2026 Localhaven) and to the files written for this template (Copyright (c) 2026 the template authors):

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
