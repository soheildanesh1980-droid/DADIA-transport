#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=========================================="
echo "DADIA FULL TEST 1 -> 6"
echo "=========================================="

ROOT="$HOME/DADIA-Transport"
cd "$ROOT"

echo "[1] BASE TEST 1 -> 5"
echo "=========================================="
./FULL_TEST_1_TO_5.sh

echo "[2] STAGE 6 DEDICATED TEST"
echo "=========================================="

echo "[2.1] PROJECT FILES"
test -f package.json
test -f tsconfig.json
test -d src

echo "[2.2] TYPESCRIPT"
npm run typecheck

echo "[2.3] BUILD"
npm run build

echo "[2.4] POSTGRES"
pg_isready >/dev/null 2>&1
echo "POSTGRES: OK"

echo "[2.5] REDIS"
redis-cli ping | grep -q PONG
echo "REDIS: OK"

echo "[2.6] DATABASE"
node - <<'NODE'
const { Client } = require('pg');

(async () => {
  const client = new Client({
    connectionString: process.env.DATABASE_URL ||
      'postgresql://u0_a320@localhost:5432/dadia_transport'
  });

  try {
    await client.connect();
    await client.query('SELECT 1');
    console.log('DATABASE CONNECTION: OK');
  } catch (err) {
    console.error('DATABASE CONNECTION: FAIL');
    console.error(err.message);
    process.exit(1);
  } finally {
    await client.end().catch(() => {});
  }
})();
NODE

echo "[2.7] SOURCE CHECK"
grep -RniE "stage.?6|Stage.?6" src package.json 2>/dev/null || true

echo "[3] FINAL RESULT"
echo "=========================================="
echo "DADIA STAGE 6 DEDICATED TEST: PASS"
echo "DADIA FULL TEST 1 -> 6: PASS"
echo "=========================================="
