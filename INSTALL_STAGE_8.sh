#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=========================================="
echo "DADIA STAGE 8 INSTALL"
echo "=========================================="

echo "[1] PROJECT CHECK"
test -d src
test -f package.json
echo "PROJECT: PASS"

echo "[2] DATABASE CHECK"
node --input-type=module <<'EOF'
import "dotenv/config";
import pg from "pg";
const { Client } = pg;

const client = new Client({
  host: process.env.POSTGRES_HOST,
  port: Number(process.env.POSTGRES_PORT),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD
});

try {
  await client.connect();
  await client.query("SELECT 1");
  console.log("DATABASE: PASS");
} catch (e) {
  console.error("DATABASE: FAIL");
  console.error(e.message);
  process.exit(1);
} finally {
  await client.end().catch(() => {});
}
EOF

echo "[3] TYPESCRIPT CHECK"
npx tsc --noEmit
echo "TYPESCRIPT: PASS"

echo "[4] STAGE 8 PREPARATION"
mkdir -p src/modules/trips
echo "TRIP ENGINE DIRECTORY: PASS"

echo "[5] EXISTING TRIP ENGINE"
test -f src/modules/trips/index.ts
grep -q '"/:id/accept"' src/modules/trips/index.ts
grep -q '"/:id/arrive"' src/modules/trips/index.ts
grep -q '"/:id/start"' src/modules/trips/index.ts
grep -q '"/:id/complete"' src/modules/trips/index.ts
echo "EXISTING TRIP CORE: PASS"

echo "=========================================="
echo "DADIA STAGE 8 INSTALL: PASS"
echo "=========================================="
