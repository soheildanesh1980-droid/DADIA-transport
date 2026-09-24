#!/data/data/com.termux/files/usr/bin/bash
set -u

PROJECT="$HOME/DADIA-Transport"
BACKUP_ROOT="$HOME/DADIA-Transport-BACKUPS"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/stage2_final_$STAMP"

mkdir -p "$BACKUP"

echo "================================"
echo "DADIA STAGE 2 FINAL REPAIR"
echo "================================"

cd "$PROJECT" || exit 1

# 1) بکاپ کامل پروژه
echo "[1/8] PROJECT BACKUP..."
tar \
  --exclude=node_modules \
  --exclude=dist \
  --exclude='*.log' \
  -czf "$BACKUP/project.tar.gz" .

# 2) بکاپ دیتابیس
echo "[2/8] DATABASE BACKUP..."

DB_NAME="dadia_transport"

if pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
  pg_dump -h 127.0.0.1 -p 5432 "$DB_NAME" \
    > "$BACKUP/dadia_transport.sql" 2>/dev/null || true
fi

# 3) اطمینان از سرویس‌ها
echo "[3/8] SERVICES..."

pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1 || {
  pg_ctl -D "$PREFIX/var/lib/postgresql" start >/dev/null 2>&1 || true
}

redis-cli ping >/dev/null 2>&1 || {
  redis-server --daemonize yes >/dev/null 2>&1 || true
}

# 4) بازنویسی اتصال PostgreSQL
echo "[4/8] POSTGRES CONNECTION..."

cat > src/database/postgres.ts <<'TS'
import pg from "pg";

const { Pool } = pg;

export const pool = new Pool({
  connectionString:
    process.env.DATABASE_URL ??
    "postgresql://dadia_app@127.0.0.1:5432/dadia_transport",
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

export async function checkPostgres(): Promise<boolean> {
  try {
    const result = await pool.query("SELECT 1 AS ok");
    return result.rows?.[0]?.ok === 1;
  } catch {
    return false;
  }
}
TS

# 5) Health را مستقیم و قابل اعتماد میکنیم
echo "[5/8] HEALTH CHECK..."

cat > src/routes/health.ts <<'TS'
import { Router } from "express";
import { checkPostgres } from "../database/postgres.js";
import { checkRedis } from "../cache/redis.js";

const router = Router();

router.get("/health", async (_req, res) => {
  const [database, redis] = await Promise.all([
    checkPostgres(),
    checkRedis(),
  ]);

  const healthy = database && redis;

  res.status(healthy ? 200 : 503).json({
    status: healthy ? "ok" : "degraded",
    service: "DADIA Transport API",
    stage: 2,
    backend: true,
    database,
    redis,
    timestamp: new Date().toISOString(),
  });
});

export default router;
TS

# 6) تست Build
echo "[6/8] BUILD..."

npm run typecheck || {
  echo "TYPECHECK FAILED"
  echo "BACKUP: $BACKUP"
  exit 1
}

npm run build || {
  echo "BUILD FAILED"
  echo "BACKUP: $BACKUP"
  exit 1
}

# 7) سرورهای قبلی را فقط از طریق PID خود پروژه متوقف میکنیم
echo "[7/8] SERVER RESTART..."

PIDFILE="$PROJECT/.dadia-server.pid"

if [ -f "$PIDFILE" ]; then
  OLD_PID="$(cat "$PIDFILE" 2>/dev/null || true)"

  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
  fi

  rm -f "$PIDFILE"
fi

# اگر پورت 3000 توسط سرور قبلی همین پروژه اشغال باشد
OLD_PIDS="$(ps -A -o pid=,args= 2>/dev/null | grep 'node dist/server.js' | grep "$PROJECT" | awk '{print $1}' || true)"

for PID in $OLD_PIDS; do
  kill "$PID" 2>/dev/null || true
done

sleep 1

nohup npm start > "$PROJECT/dadia-stage2.log" 2>&1 &
SERVER_PID=$!

echo "$SERVER_PID" > "$PIDFILE"

sleep 3

# 8) تست نهایی
echo "[8/8] FINAL TEST..."

POSTGRES_RESULT="$(
node --env-file=.env --input-type=module -e '
import pg from "pg";
const {Pool}=pg;
const pool=new Pool({connectionString:process.env.DATABASE_URL});
try {
  const r=await pool.query("SELECT 1 AS ok");
  console.log(r.rows[0].ok===1 ? "OK" : "FAIL");
} catch(e) {
  console.log("FAIL");
}
await pool.end();
' 2>/dev/null
)"

REDIS_RESULT="$(redis-cli ping 2>/dev/null || true)"

HEALTH_RESULT="$(curl -s --max-time 5 http://127.0.0.1:3000/health 2>/dev/null || true)"

echo
echo "POSTGRES DIRECT: $POSTGRES_RESULT"
echo "REDIS: $REDIS_RESULT"
echo "HEALTH: $HEALTH_RESULT"
echo "BACKUP: $BACKUP"
echo "================================"

if echo "$HEALTH_RESULT" | grep -q '"status":"ok"' &&
   echo "$HEALTH_RESULT" | grep -q '"database":true' &&
   echo "$HEALTH_RESULT" | grep -q '"redis":true' &&
   [ "$POSTGRES_RESULT" = "OK" ] &&
   [ "$REDIS_RESULT" = "PONG" ]; then

  echo
  echo "================================"
  echo "DADIA STAGE 2: PASS"
  echo "================================"
  echo "BACKUP SAVED: $BACKUP"
else
  echo
  echo "================================"
  echo "DADIA STAGE 2: FAILED"
  echo "BACKUP SAVED: $BACKUP"
  echo "================================"
  echo
  echo "BACKEND LOG:"
  tail -n 80 "$PROJECT/dadia-stage2.log" 2>/dev/null || true
  exit 1
fi
