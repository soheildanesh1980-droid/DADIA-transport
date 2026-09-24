#!/data/data/com.termux/files/usr/bin/bash
set -u

PROJECT="$HOME/DADIA-Transport"
BACKUP_ROOT="$HOME/DADIA-Transport-BACKUPS"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/stage2_serverfix_$STAMP"

mkdir -p "$BACKUP"
cd "$PROJECT" || exit 1

echo "================================"
echo "DADIA STAGE 2 SERVER FIX"
echo "================================"

echo "[1/7] BACKUP..."
tar --exclude=node_modules --exclude=dist --exclude='*.log' \
  -czf "$BACKUP/project.tar.gz" .

echo "[2/7] STOP OLD DADIA SERVERS..."

# فقط node هایی که دقیقا dist/server.js را اجرا میکنند
for PID in $(ps -A -o pid=,args= 2>/dev/null | awk '$2=="node" && $3=="dist/server.js" {print $1}'); do
  kill "$PID" 2>/dev/null || true
done

sleep 2

# PID قبلی
rm -f .dadia-server.pid

echo "[3/7] CLEAN BUILD..."

rm -rf dist

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

echo "[4/7] DIRECT DATABASE TEST..."

DB_TEST="$(
node --env-file=.env --input-type=module <<'JS'
import pg from "pg";

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

try {
  const r = await pool.query("SELECT 1 AS ok");
  console.log(r.rows[0].ok === 1 ? "OK" : "FAIL");
} catch (e) {
  console.log("FAIL");
}

await pool.end();
JS
)"

echo "POSTGRES DIRECT: $DB_TEST"

if [ "$DB_TEST" != "OK" ]; then
  echo "POSTGRES TEST FAILED"
  echo "BACKUP: $BACKUP"
  exit 1
fi

echo "[5/7] START FRESH API..."

nohup node --env-file=.env dist/server.js > dadia-stage2.log 2>&1 &
SERVER_PID=$!

echo "$SERVER_PID" > .dadia-server.pid

sleep 3

echo "[6/7] API TEST..."

HEALTH="$(curl -s --max-time 5 http://127.0.0.1:3000/health 2>/dev/null || true)"

echo "HEALTH: $HEALTH"

echo "[7/7] FINAL VALIDATION..."

REDIS="$(redis-cli ping 2>/dev/null || true)"

echo "REDIS: $REDIS"

if echo "$HEALTH" | grep -q '"status":"ok"' &&
   echo "$HEALTH" | grep -q '"database":true' &&
   echo "$HEALTH" | grep -q '"redis":true' &&
   [ "$REDIS" = "PONG" ]; then

  echo
  echo "================================"
  echo "DADIA STAGE 2: PASS"
  echo "================================"
  echo "BACKUP: $BACKUP"
else

  echo
  echo "================================"
  echo "DADIA STAGE 2: FAILED"
  echo "================================"
  echo "BACKUP: $BACKUP"
  echo
  echo "LOG:"
  tail -n 80 dadia-stage2.log 2>/dev/null || true
  exit 1
fi
