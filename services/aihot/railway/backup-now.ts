// AIHOT on Railway (community template): one backup right now, the same run as the worker's daily
// ops.backup job (pg_dump of the database plus the uploaded files, uploaded to the Railway Bucket under
// daily/, weekly/ or monthly/). Use it to check the Bucket wiring or before an upgrade:
//   in the Backend service:  node /app/railway/backup-now.ts
//   or set TEMPLATE_BACKUP_ON_BOOT=true on Backend and redeploy (runs once after the API is up).
// The object store comes from the environment that railway/entrypoint.sh prepares (DB_BACKUP_STORE_*).
import { backupConfigured, runBackup } from "@aihot/backend/operations/backup";
import { closeDb } from "@aihot/backend/db";

const deriveDomain = (): void => {
  // Same derivation as entrypoint.sh, for a shell that did not go through it (railway ssh, railway run).
  const bucket = process.env.DB_BACKUP_STORE_BUCKET;
  const endpoint = process.env.TEMPLATE_BACKUP_ENDPOINT;
  if (bucket && endpoint && !process.env.DB_BACKUP_STORE_DOMAIN) {
    process.env.DB_BACKUP_STORE_DOMAIN = `${bucket}.${endpoint.replace(/^[a-z]+:\/\//i, "").split("/")[0]}`;
  }
};

deriveDomain();
if (process.env.TEMPLATE_BACKUPS && process.env.TEMPLATE_BACKUPS !== "true") {
  console.error(JSON.stringify({ level: "error", msg: "backup-now: TEMPLATE_BACKUPS is not true, nothing done" }));
  process.exit(2);
}
if (!backupConfigured()) {
  console.error(JSON.stringify({ level: "error", msg: "backup-now: no object store (DB_BACKUP_STORE_SECRET_ID, _SECRET_KEY, _BUCKET, _REGION); nothing done" }));
  process.exit(2);
}

try {
  const summary = await runBackup();
  console.log(JSON.stringify({ level: "info", msg: "backup-now: uploaded", ...summary }));
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(JSON.stringify({ level: "error", msg: "backup-now: failed", error: message.slice(0, 500) }));
  process.exitCode = 1;
} finally {
  await closeDb();
}
