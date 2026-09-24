#!/data/data/com.termux/files/usr/bin/bash
set -u

PROJECT="$HOME/DADIA-Transport"
BACKUP="$HOME/DADIA-Transport-BACKUPS/stage2_FINAL_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP"
cd "$PROJECT" || exit 1

echo "================================"
echo "DADIA STAGE 2 FINAL"
echo "================================"

echo "[1] BACKUP PROJECT"
tar --exclude=node_modules --exclude=dist --exclude='*.log' \
  -czf "$BACKUP/project.tar.gz" .

echo "[2] BACKUP DATABASE"
pg_dump -h 127.0.0.1 -p 5432 dadia_transport \
  > "$BACKUP/dadia_transport.sql" 2>/dev/null || true

echo "[3] WRITE DEFINITIVE POSTGRES CHECK"

cat > src/database/postgres.ts <<'TS'
import pg from "pg";

const { Client } = pg;

export async function checkPostgres(): Promise<boolean> {
  const connectionString =
    process.env.DATABASE_URL ??
    "postgresql://dadia_app@127.0.0.1:5432/dadia_transport";

  const client = new Client({
    connectionString,
    connectionTimeoutMillis: 5000,
  });

  try {
    await client.connect();
    const result = await client.query("SELECT 1 AS ok");

    console.log("POSTGRES HEALTH:", result.rows[0]?.ok === 1 ? "OK" : "FAIL");

    await client.end();
    return result.rows[0]?.ok === 1;
  } catch (error) {
    console.error("POSTGRES HEALTH ERROR:", error);
    try {
      await client.end();
    } catch {}
    return false;
  }
}
TS

echo "[4] WRITE DEFINITIVE HEALTH"

cat > src/routes/health.ts <<'TS'
import { Router } from "express";
import { checkPostgres } from "../database/postgres.js";
import { checkRedis } from "../cache/redis.js";

const router = Router();

router.get("/health", async (_req, res) => {
  const database = await checkPostgres();
  const redis = await checkRedis();

  const status = database && redis ? "ok" : "degraded";

  res.status(status === "ok" ? 200 : 503).json({
    status,
    service: "DADIA Transport API",
    stage: 2,
    backend: true,
    database,
    redis,
    timestamp: new Date().toISOString()
  });
});

export default router;
TS

echo "[5] TYPECHECK + BUILD"

npm run typecheck || exit 1
npm run build || exit 1

echo "[6] STOP OLD SERVER"

if [ -f .dadia-server.pid ]; then
  PID="$(cat .dadia-server.pid 2>/dev/null || true)"
  [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
fi

for PID in $(ps -A -o pid=,args= 2>/dev/null | \
  awk '$0 ~ /node.*dist\/server\.js/ {print $1}'); do
  kill "$PID" 2>/dev/null || true
done

rm -f .dadia-server.pid
sleep 2

echo "[7] START CLEAN SERVER"

nohup node --env-file=.env dist/server.js > dadia-stage2.log 2>&1 &
PID=$!
echo "$PID" > .dadia-server.pid

sleep 3

echo "[8] FINAL HEALTH"

HEALTH="$(curl -s --max-time 8 http://127.0.0.1:3000/health 2>/dev/null || true)"

echo
echo "HEALTH:"
echo "$HEALTH"
echo
echo "BACKUP: $BACKUP"
echo

if echo "$HEALTH" | grep -q '"status":"ok"' &&
   echo "$HEALTH" | grep -q '"database":true' &&
   echo "$HEALTH" | grep -q '"redis":true'; then

  echo "================================"
  echo "DADIA STAGE 2: PASS"
  echo "================================"
  exit 0
fi

echo "================================"
echo "DADIA STAGE 2: FAILED"
echo "================================"
echo
echo "ACTUAL SERVER ERROR:"
tail -n 100 dadia-stage2.log

exit 1
