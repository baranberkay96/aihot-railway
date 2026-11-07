# Deploy and Host AIHOT with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/aihot-2026-11-ai-hot-topics-site?referralCode=20H68q)

AIHOT is an open-source news site that runs itself. It collects items from your sources, lets a language model screen and score each one twice, writes a headline and summary, groups reports of the same story into one event, ranks events by how many sources discuss them, and publishes a daily report.

## About Hosting AIHOT

This community template runs AIHOT's snapshot 2026.11 (upstream has no releases, so it builds a pinned commit, checksum-verified) the way upstream's Docker setup does: a site process, an API and a background worker on PostgreSQL 17, with a Caddy front for compression and security headers, and daily backups to a Railway Bucket.

Read this before deploying: **the interface and everything the site writes are in Simplified Chinese** (upstream design). The 18 demo sources are English AI news feeds. You need an API key for an OpenAI-compatible model service; DeepSeek is the default. The admin password is generated for you.

## Common Use Cases

- A self-updating AI news site with a daily report, weekly and monthly roundups, and a trending list
- Your own field's news site: fork AIHOT, change the sources, scoring prompts and thresholds, and point this template at your fork
- A curated feed for AI agents and readers: RSS, a public JSON API, an MCP server and `llms.txt`
- Spotting what many sources talk about at once (heat per event, rising and new markers)
- A Chinese-language AI digest for readers and teams who read Chinese

## Dependencies for AIHOT Hosting

- An API key for any OpenAI-compatible chat model (DeepSeek, OpenAI, OpenRouter, Qwen, GLM and others). Model calls are billed by that provider.
- Included: PostgreSQL 17, a volume for images and uploads, and a Railway Bucket for backups
- Optional: an embeddings API for better event grouping, SocialData (X accounts), Jina Reader (hard-to-fetch pages)

### Deployment Dependencies

- [AIHOT on GitHub](https://github.com/KKKKhazix/AIHOT) (MIT), pinned commit [0ce2d00fd80b](https://github.com/KKKKhazix/AIHOT/tree/0ce2d00fd80be416d78d675df732d5e1bef53b40)
- [English README](https://github.com/KKKKhazix/AIHOT/blob/main/README.en.md) and upstream docs (Chinese): [deploy](https://github.com/KKKKhazix/AIHOT/blob/main/docs/deploy.md), [make it your field](https://github.com/KKKKhazix/AIHOT/blob/main/docs/customize.md), [sources](https://github.com/KKKKhazix/AIHOT/blob/main/docs/sources.md)
- [DeepSeek API docs](https://api-docs.deepseek.com/) for the default model service

### Implementation Details

| Service | What it does | Public |
|---|---|---|
| Gateway | Caddy: compression, security headers, real visitor IPs, `/gateway-health` | yes |
| Web | Server-rendered site; forwards API paths (`/api/*`, RSS, sitemap, images, MCP) to Backend | no |
| Backend | API and worker in one container (they share the `/data` volume): collection, model steps, grouping, heat, reports, backups. Runs migrations and adds the demo sources before each deploy | no |
| Postgres | PostgreSQL 17, the version upstream tests | no |
| Backups | Railway Bucket for the daily `pg_dump` and uploaded files | no |

**First steps**

1. Paste your model key into `LLM_API_KEY` at deploy. For another provider also change `LLM_BASE_URL` and `LLM_MODEL`, and clear `LLM_EXTRA_JSON` if the provider rejects unknown fields (OpenAI does). Reasoning models also need `LLM_REASONING_TOKENS`, for example `4000`.
2. Wait for the three builds (about 5 to 10 minutes). Open `https://{your-domain}`. Items appear within minutes; the first import of about 150 items takes roughly half an hour to score and write up.
3. The admin is at `https://{your-domain}/admin`. The password is `ADMIN_PASSWORD` in the Backend variables. Sources, content diagnostics, model usage per step, paid-service budgets and run history are there.
4. **The first daily report** is written at the first 08:00 China Standard Time (00:00 UTC) after your deploy (the next one if you deploy shortly before), from the items scored since the first import. Items from a source's first import are archived by their publish date and stay out of reports, so until then the admin's Runs page shows "nothing judged in its window" for `reports.compose`. That is expected. Weekly reports follow on Monday 10:00 and monthly reports on the 1st at 10:30 (China time).

**Good to know**

- Upstream does not let you change language, site name (MyHOT), report times or prompts through variables; they live in `site/` and `industry/` of the code. Make a public repo with upstream's "Use this template" button, edit it (upstream's guide works well with a coding agent), then set `AIHOT_SOURCE_REPO` (owner/name) and `AIHOT_SOURCE_COMMIT` (full SHA) on Backend and redeploy Backend and Web. Add `AIHOT_SOURCE_SHA256` from the build log to make later builds verified. The upstream author asks that sites use their own name and logo, not AIHOT's.
- Add or pause sources in the admin. Each deploy re-adds missing demo sources (as upstream's setup step does), so pause them rather than delete them, or set `TEMPLATE_SEED_SOURCES=false`.
- `COLLECT_ENABLED` and `MODEL_CALLS_ENABLED` are upstream's safety valves; set either to `false` to stop collection or model spending at once.
- A custom domain: add it to Gateway, then set `SITE_URL` on Web to `https://{your-domain}` (links, RSS and the MCP host check use it).
- Agents connect at `https://{your-domain}/api/mcp`; the `/agent` page shows MCP, RSS and API details.
- Optional pushes to Feishu or DingTalk and Feishu sign-in work with upstream's variables (see `.env.example` upstream).

**Backups:** the worker dumps the database and the uploaded files every day at 04:10 China time into the Backups bucket (`daily/`, `weekly/` on Sundays, `monthly/` on the 1st). The template sets no expiry rule, so delete old backups now and then. To test it, set `TEMPLATE_BACKUP_ON_BOOT=true` on Backend, redeploy, look for `backup-now: uploaded` in the logs, then set it back.

**Scaling:** Backend stays at one replica (it owns the volume). Give it more memory if image processing is busy. Web and Gateway are stateless and can run more replicas. Costs grow with the number of new items per day, mostly at your model provider.

**Cost (estimate, not measured):** about $7 a month idle and $15 to $20 with daily traffic on Railway (Hobby plan), plus model calls. Upstream measured about 930 model calls for its first 152 items; the admin's Models page shows calls and tokens per step.

**Versions:** AIHOT `0ce2d00fd80b` (2026-11-07) from the codeload tarball, SHA-256 verified; Node 24.22.2, Caddy 2.11.9 and `postgres-ssl:17`, all pinned. To upgrade, back up first, then build a newer commit with the `AIHOT_SOURCE_*` variables (or redeploy after this template's repo moves its pin). Backend's pre-deploy step runs the new migrations. Check upstream's update notes in `docs/deploy.md` first.

### Why Deploy AIHOT on Railway?

AIHOT needs a database, a long-running worker, a public site and somewhere safe to keep backups. Railway runs all of them from one template, with private networking, HTTPS, logs and metrics, and you pay only for what the services use.

This is a community template. It is not made, endorsed or supported by the AIHOT author. AIHOT's name and logo belong to its author; the deployed site uses its own default name, MyHOT.
