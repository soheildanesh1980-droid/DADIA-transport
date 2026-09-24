#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

PROJECT="$HOME/DADIA-Transport"
BACKUP_ROOT="$HOME/DADIA-Transport-BACKUPS"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/stage2_repair_$STAMP"
PGDATA="$PREFIX/var/lib/postgresql"

cd "$PROJECT"
mkdir -p "$BACKUP"

echo "================================"
echo "DADIA STAGE 2 REPAIR V2"
echo "================================"

echo "[1/9] Backup..."
tar -czf "$BACKUP/project.tar.gz" \
  --exclude='./node_modules' \
  --exclude='./dist' \
  --exclude='./dadia-stage2.log' \
  .

echo "[2/9] PostgreSQL..."
if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  pg_ctl -D "$PGDATA" -l "$PREFIX/var/log/postgresql.log" start
fi

until pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; do
  sleep 1
done

echo "[3/9] Database..."
psql -h 127.0.0.1 -d postgres -v ON_ERROR_STOP=1 <<'SQL'
SELECT 'PostgreSQL connection OK';
SQL

if ! psql -h 127.0.0.1 -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname='dadia_transport'" | grep -q 1; then
  createdb -h 127.0.0.1 dadia_transport
fi

echo "[4/9] Application user..."

DADIA_DB_USER="dadia_app"
DADIA_DB_PASS="$(node -e "console.log(require('crypto').randomBytes(24).toString('hex'))")"

ROLE_EXISTS="$(psql -h 127.0.0.1 -d postgres -tAc \
  "SELECT 1 FROM pg_roles WHERE rolname='${DADIA_DB_USER}'" | tr -d '[:space:]')"

if [ "$ROLE_EXISTS" = "1" ]; then
  psql -h 127.0.0.1 -d postgres -v ON_ERROR_STOP=1 \
    -c "ALTER ROLE \"$DADIA_DB_USER\" WITH LOGIN PASSWORD '$DADIA_DB_PASS';"
else
  psql -h 127.0.0.1 -d postgres -v ON_ERROR_STOP=1 \
    -c "CREATE ROLE \"$DADIA_DB_USER\" LOGIN PASSWORD '$DADIA_DB_PASS';"
fi

echo "[5/9] Permissions..."

psql -h 127.0.0.1 -d postgres -v ON_ERROR_STOP=1 \
  -c "GRANT ALL PRIVILEGES ON DATABASE dadia_transport TO \"$DADIA_DB_USER\";"

psql -h 127.0.0.1 -d dadia_transport -v ON_ERROR_STOP=1 <<SQL
GRANT USAGE, CREATE ON SCHEMA public TO "$DADIA_DB_USER";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "$DADIA_DB_USER";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "$DADIA_DB_USER";
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO "$DADIA_DB_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "$DADIA_DB_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "$DADIA_DB_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO "$DADIA_DB_USER";
SQL

echo "[6/9] Environment..."

cp .env "$BACKUP/.env.before" 2>/dev/null || true

cat > .env <<ENV
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://${DADIA_DB_USER}:${DADIA_DB_PASS}@127.0.0.1:5432/dadia_transport
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
ENV

echo "[7/9] Build..."

npm run typecheck
npm run build

echo "[8/9] Direct Node database test..."

DB_RESULT="$(
node --env-file=.env --input-type=module <<'NODE'
import pg from "pg";

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL
});

try {
  const r = await pool.query("SELECT 1 AS ok");
  console.log(r.rows[0].ok === 1 ? "OK" : "FAIL");
} catch (e) {
  console.log("FAIL");
  console.error(e.message);
  process.exitCode = 1;
} finally {
  await pool.end();
}
NODE
)"

echo "POSTGRES DIRECT: $DB_RESULT"

echo "[9/9] Backend + Redis + Health..."

redis-server --daemonize yes >/dev/null 2>&1 || true

pkill -f "node dist/server.js" 2>/dev/null || true
nohup npm start > dadia-stage2.log 2>&1 &

sleep 3

REDIS_RESULT="$(redis-cli ping 2>/dev/null || true)"
HEALTH="$(curl -s --max-time 5 http://127.0.0.1:3000/health || true)"

echo
echo "================================"
echo "POSTGRES DIRECT: $DB_RESULT"
echo "REDIS: $REDIS_RESULT"
echo "HEALTH: $HEALTH"
echo "BACKUP: $BACKUP"
echo "================================"

if [ "$DB_RESULT" = "OK" ] &&
   [ "$REDIS_RESULT" = "PONG" ] &&
   echo "$HEALTH" | grep -q '"status":"ok"' &&
   echo "$HEALTH" | grep -q '"database":true' &&
   echo "$HEALTH" | grep -q '"redis":true'; then

  echo
  echo "DADIA STAGE 2: PASS"
  echo "BACKUP SAVED: $BACKUP"
else
  echo
  echo "DADIA STAGE 2: FAILED"
  echo "BACKUP SAVED: $BACKUP"
  echo
  echo "BACKEND LOG:"
  tail -30 dadia-stage2.log
  exit 1
fi
