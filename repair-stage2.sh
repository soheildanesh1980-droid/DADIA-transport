#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

PROJECT="$HOME/DADIA-Transport"
BACKUP_ROOT="$HOME/DADIA-Transport-BACKUPS"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/stage2_$STAMP"
PGDATA="$PREFIX/var/lib/postgresql"

cd "$PROJECT"

echo "================================"
echo "DADIA STAGE 2 SELF-REPAIR"
echo "================================"

mkdir -p "$BACKUP"

# --------------------------------------------------
# 1) BACKUP کامل کد و تنظیمات
# --------------------------------------------------
echo "[1/10] Project backup..."

tar -czf "$BACKUP/project.tar.gz" \
  --exclude='./node_modules' \
  --exclude='./dist' \
  --exclude='./dadia-stage2.log' \
  .

# --------------------------------------------------
# 2) اطمینان از سرویس PostgreSQL
# --------------------------------------------------
echo "[2/10] PostgreSQL..."

if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  pg_ctl -D "$PGDATA" -l "$PREFIX/var/log/postgresql.log" start
fi

for i in $(seq 1 20); do
  if pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

pg_isready -h 127.0.0.1 -p 5432

# --------------------------------------------------
# 3) Backup دیتابیس موجود
# --------------------------------------------------
echo "[3/10] Database backup..."

if psql -h 127.0.0.1 -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname='dadia_transport'" | grep -q 1; then

  pg_dump -h 127.0.0.1 -d dadia_transport \
    > "$BACKUP/dadia_transport.sql"

  pg_dumpall -h 127.0.0.1 --globals-only \
    > "$BACKUP/postgresql_globals.sql"
else
  echo "Database does not exist yet; no DB dump required."
fi

# --------------------------------------------------
# 4) ساخت کاربر اختصاصی DADIA
# --------------------------------------------------
echo "[4/10] Creating DADIA database user..."

DADIA_DB_USER="dadia_app"
DADIA_DB_PASS="$(node -e "console.log(require('crypto').randomBytes(24).toString('hex'))")"

psql -h 127.0.0.1 -d postgres -v ON_ERROR_STOP=1 \
  -v app_user="$DADIA_DB_USER" \
  -v app_pass="$DADIA_DB_PASS" <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_roles WHERE rolname = :'app_user'
  ) THEN
    EXECUTE format(
      'CREATE ROLE %I LOGIN PASSWORD %L',
      :'app_user',
      :'app_pass'
    );
  ELSE
    EXECUTE format(
      'ALTER ROLE %I WITH LOGIN PASSWORD %L',
      :'app_user',
      :'app_pass'
    );
  END IF;
END
$$;
SQL

# --------------------------------------------------
# 5) ایجاد دیتابیس در صورت نیاز
# --------------------------------------------------
echo "[5/10] Creating database..."

if ! psql -h 127.0.0.1 -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname='dadia_transport'" | grep -q 1; then

  createdb -h 127.0.0.1 -O "$DADIA_DB_USER" dadia_transport
fi

# --------------------------------------------------
# 6) مجوزها
# --------------------------------------------------
echo "[6/10] Fixing database permissions..."

psql -h 127.0.0.1 -d postgres -v ON_ERROR_STOP=1 <<SQL
GRANT ALL PRIVILEGES ON DATABASE dadia_transport TO "$DADIA_DB_USER";
SQL

psql -h 127.0.0.1 -d dadia_transport -v ON_ERROR_STOP=1 <<SQL
GRANT ALL ON SCHEMA public TO "$DADIA_DB_USER";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "$DADIA_DB_USER";
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "$DADIA_DB_USER";
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO "$DADIA_DB_USER";

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON TABLES TO "$DADIA_DB_USER";

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON SEQUENCES TO "$DADIA_DB_USER";

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON FUNCTIONS TO "$DADIA_DB_USER";
SQL

# --------------------------------------------------
# 7) اصلاح .env بدون حذف تنظیمات دیگر
# --------------------------------------------------
echo "[7/10] Repairing environment..."

node <<NODE
const fs = require("fs");

const file = ".env";
let text = fs.existsSync(file) ? fs.readFileSync(file, "utf8") : "";

const values = {
  DATABASE_URL:
    "postgresql://${DADIA_DB_USER}:${DADIA_DB_PASS}@127.0.0.1:5432/dadia_transport",
  REDIS_HOST: "127.0.0.1",
  REDIS_PORT: "6379",
  NODE_ENV: "development",
  PORT: "3000"
};

const lines = text.split(/\\r?\\n/).filter(Boolean);

for (const [key, value] of Object.entries(values)) {
  const index = lines.findIndex(line => line.startsWith(key + "="));

  if (index >= 0) {
    lines[index] = key + "=" + value;
  } else {
    lines.push(key + "=" + value);
  }
}

fs.writeFileSync(file, lines.join("\\n") + "\\n");
NODE

# --------------------------------------------------
# 8) اصلاح npm start برای بارگذاری قطعی .env
# --------------------------------------------------
echo "[8/10] Repairing npm start..."

node <<'NODE'
const fs = require("fs");

const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));

pkg.scripts = {
  ...(pkg.scripts || {}),
  dev: "tsx watch src/server.ts",
  build: "tsc",
  start: "node --env-file=.env dist/server.js",
  typecheck: "tsc --noEmit"
};

fs.writeFileSync(
  "package.json",
  JSON.stringify(pkg, null, 2) + "\n"
);
NODE

# --------------------------------------------------
# 9) Build
# --------------------------------------------------
echo "[9/10] Typecheck + build..."

npm run typecheck
npm run build

# --------------------------------------------------
# 10) تست واقعی DB + Redis + API
# --------------------------------------------------
echo "[10/10] Final integration test..."

# Redis
redis-server --daemonize yes >/dev/null 2>&1 || true

# اجرای Backend با .env واقعی
pkill -f "node dist/server.js" 2>/dev/null || true

nohup npm start > dadia-stage2.log 2>&1 &
SERVER_PID=$!

sleep 3

# تست مستقیم PostgreSQL با همان اطلاعات .env
DB_RESULT="$(
node --env-file=.env --input-type=module <<'NODE'
import pg from "pg";

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL
});

try {
  const result = await pool.query("SELECT 1 AS ok");
  console.log(result.rows[0].ok === 1 ? "OK" : "FAIL");
} catch (error) {
  console.log("FAIL");
  process.exitCode = 1;
} finally {
  await pool.end();
}
NODE
)"

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
  echo "DADIA STAGE 2 SELF-REPAIR: PASS"
  echo "BACKUP SAVED: $BACKUP"
  exit 0
fi

echo
echo "DADIA STAGE 2 SELF-REPAIR: FAILED"
echo "BACKUP SAVED: $BACKUP"
echo
echo "Last backend log:"
tail -30 dadia-stage2.log
exit 1
