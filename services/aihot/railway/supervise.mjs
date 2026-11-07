// AIHOT on Railway (community template): runs the API and the worker side by side in the Backend service.
//
// Upstream's docker-compose gives api and worker one shared `data` volume: the worker prepares image
// renditions, AVIF variants and share images that the API serves, packs the API's uploads into the
// backups and prunes the API's caches. A Railway volume belongs to one service, so both processes live
// here (Rule 3b of the template standard).
//
// - A process that exits is started again after a short backoff; the other keeps running.
// - SIGTERM (redeploy, stop) stops the worker first, so the API keeps answering while the worker lets
//   in-flight paid model calls and backups finish (up to 470 s upstream), then stops the API.
// - Ten quick failures in a row of one process exit the container, so Railway shows the crash and
//   applies its restart policy.
// - TEMPLATE_BACKUP_ON_BOOT=true runs one backup (railway/backup-now.ts) once the API answers.
import { spawn } from "node:child_process";
import path from "node:path";

const APP_DIR = "/app";
const PROCESSES = {
  worker: ["apps/worker/src/main.ts"],
  api: ["apps/api/src/main.ts"],
};
const BACKOFF_MS = [1_000, 5_000, 15_000, 30_000, 60_000];
const STABLE_MS = 5 * 60_000;
const MAX_QUICK_FAILURES = 10;

const log = (level, msg, extra = {}) =>
  (level === "error" ? console.error : console.log)(JSON.stringify({ level, msg: `railway supervisor: ${msg}`, ...extra }));

const state = Object.fromEntries(Object.keys(PROCESSES).map((name) => [name, { child: null, startedAt: 0, failures: 0, timer: null }]));
/** One-off helpers (the optional boot backup), stopped together with the processes. */
const extras = new Set();
let stopping = false;

function start(name) {
  const s = state[name];
  s.timer = null;
  if (stopping) return;
  const child = spawn(process.execPath, PROCESSES[name], { cwd: APP_DIR, stdio: "inherit", env: process.env });
  s.child = child;
  s.startedAt = Date.now();
  log("info", `${name} started`, { pid: child.pid });
  child.on("error", (error) => log("error", `${name} could not be started`, { error: String(error) }));
  child.on("exit", (code, signal) => {
    s.child = null;
    if (stopping) return;
    const ranMs = Date.now() - s.startedAt;
    s.failures = ranMs >= STABLE_MS ? 1 : s.failures + 1;
    if (s.failures >= MAX_QUICK_FAILURES) {
      log("error", `${name} exited ${s.failures} times in a row; stopping the container`, { code, signal });
      void shutdown(1);
      return;
    }
    const delay = BACKOFF_MS[Math.min(s.failures - 1, BACKOFF_MS.length - 1)];
    log("error", `${name} exited; starting it again in ${delay / 1000}s`, { code, signal, ranSeconds: Math.round(ranMs / 1000) });
    s.timer = setTimeout(() => start(name), delay);
  });
}

function stop(name) {
  const s = state[name];
  if (s.timer) {
    clearTimeout(s.timer);
    s.timer = null;
  }
  const child = s.child;
  if (!child) return Promise.resolve();
  return new Promise((resolve) => {
    child.once("exit", () => resolve());
    child.kill("SIGTERM");
  });
}

async function shutdown(code) {
  if (stopping) return;
  stopping = true;
  const started = Date.now();
  log("info", "stopping the worker first, then the API");
  for (const extra of extras) extra.kill("SIGTERM");
  await stop("worker");
  await stop("api");
  log("info", "stopped", { seconds: Math.round((Date.now() - started) / 1000) });
  process.exit(code);
}

process.on("SIGTERM", () => void shutdown(0));
process.on("SIGINT", () => void shutdown(0));

// ── Optional one-off backup once the API is up (exercises the Bucket wiring) ─────────────────
async function apiAnswers() {
  const port = process.env.API_PORT || process.env.PORT || "3001";
  try {
    const res = await fetch(`http://127.0.0.1:${port}/api/health`, { signal: AbortSignal.timeout(5_000) });
    return res.ok;
  } catch {
    return false;
  }
}

async function backupOnBoot() {
  for (let i = 0; i < 120 && !stopping; i++) {
    if (await apiAnswers()) break;
    await new Promise((resolve) => setTimeout(resolve, 5_000));
  }
  if (stopping) return;
  log("info", "TEMPLATE_BACKUP_ON_BOOT=true: running one backup now");
  const child = spawn(process.execPath, [path.join(APP_DIR, "railway/backup-now.ts")], { cwd: APP_DIR, stdio: "inherit", env: process.env });
  extras.add(child);
  child.on("exit", (code) => {
    extras.delete(child);
    log(code === 0 ? "info" : "error", `one-off backup finished with exit code ${code}`);
  });
}

start("worker");
start("api");
if (process.env.TEMPLATE_BACKUP_ON_BOOT === "true") void backupOnBoot();
