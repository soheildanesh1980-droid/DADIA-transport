#!/data/data/com.termux/files/usr/bin/bash
set -u

cd "$HOME/DADIA-Transport" || exit 1

echo "=========================================="
echo " DADIA STAGE 1 + 2 FULL INTEGRATION TEST"
echo "=========================================="

FAIL=0

echo
echo "[1/9] NODE / NPM"
node -v
npm -v

echo
echo "[2/9] TYPESCRIPT"
npm run typecheck || FAIL=1

echo
echo "[3/9] BUILD"
npm run build || FAIL=1

echo
echo "[4/9] POSTGRES SERVICE"
if pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
  echo "POSTGRES SERVICE: OK"
else
  echo "POSTGRES SERVICE: FAIL"
  FAIL=1
fi

echo
echo "[5/9] REDIS SERVICE"
REDIS="$(redis-cli ping 2>/dev/null || true)"
echo "REDIS: $REDIS"

if [ "$REDIS" != "PONG" ]; then
  FAIL=1
fi

echo
echo "[6/9] DIRECT DATABASE"
DB="$(node --env-file=.env --input-type=module <<'JS'
import pg from "pg";

const { Client } = pg;

const client = new Client({
  host: process.env.POSTGRES_HOST,
  port: Number(process.env.POSTGRES_PORT),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  connectionTimeoutMillis: 5000
});

try {
  await client.connect();
  const r = await client.query("SELECT 1 AS ok");
  console.log(r.rows[0]?.ok === 1 ? "OK" : "FAIL");
} catch {
  console.log("FAIL");
} finally {
  try { await client.end(); } catch {}
}
JS
)"

echo "POSTGRES DIRECT: $DB"

if [ "$DB" != "OK" ]; then
  FAIL=1
fi

echo
echo "[7/9] FULL APP ON TEST PORT"

rm -f .integration-test.mjs

cat > .integration-test.mjs <<'JS'
import app from "./dist/app.js";

const server = app.listen(3101, "127.0.0.1", async () => {
  try {
    const checks = [
      ["/health", "HEALTH"],
      ["/passenger", "PASSENGER"],
      ["/driver", "DRIVER"],
      ["/admin", "ADMIN"]
    ];

    let failed = false;

    for (const [path, name] of checks) {
      const r = await fetch(`http://127.0.0.1:3101${path}`);
      const body = await r.text();

      console.log(`${name}: HTTP ${r.status}`);
      console.log(`${name} BODY: ${body}`);

      if (r.status !== 200) {
        failed = true;
      }

      if (
        path === "/health" &&
        (
          !body.includes('"status":"ok"') ||
          !body.includes('"database":true') ||
          !body.includes('"redis":true')
        )
      ) {
        failed = true;
      }
    }

    server.close(() => process.exit(failed ? 1 : 0));

  } catch (error) {
    console.error("INTEGRATION ERROR:", error);
    server.close(() => process.exit(2));
  }
});
JS

node --env-file=.env .integration-test.mjs
APP_RESULT=$?

rm -f .integration-test.mjs

if [ "$APP_RESULT" -ne 0 ]; then
  FAIL=1
fi

echo
echo "[8/9] PRODUCTION SERVER"

if [ -f .dadia-server.pid ]; then
  PID="$(cat .dadia-server.pid 2>/dev/null || true)"

  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "SERVER PROCESS: OK"
  else
    echo "SERVER PROCESS: NOT RUNNING"
  fi
else
  echo "SERVER PID FILE: NOT FOUND"
fi

echo
echo "[9/9] FINAL RESULT"
echo "=========================================="

if [ "$FAIL" -eq 0 ]; then
  echo "DADIA STAGE 1 + 2: PASS"
  echo "=========================================="
  echo "Stage 1: REST API + TypeScript + Modules"
  echo "Stage 2: PostgreSQL + Redis + Health"
  echo "Integration: PASS"
else
  echo "DADIA STAGE 1 + 2: FAILED"
  echo "=========================================="
  exit 1
fi
