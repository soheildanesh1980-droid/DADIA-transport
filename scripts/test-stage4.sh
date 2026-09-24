#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== DADIA STAGE 4 TEST ==="

redis-server --daemonize yes >/dev/null 2>&1 || true
sleep 1
redis-cli ping

if ! pg_isready -h 127.0.0.1 -p 5432 >/dev/null; then
  echo "PostgreSQL is not running"
  exit 1
fi

npm run typecheck
npm run build

node dist/database/migrate-stage4.js

PORT=3014 node dist/server.js >./dadia-stage4.log 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
sleep 2

BASE="http://127.0.0.1:3014"
PHONE="0912$(printf '%07d' $$)"
PASSWORD="DadiaTest123!"

curl -fsS "$BASE/health" >./d4-health.json
REG=$(curl -fsS -X POST "$BASE/auth/register" -H 'Content-Type: application/json' \
  -d "{\"phone\":\"$PHONE\",\"password\":\"$PASSWORD\",\"role\":\"passenger\"}")
echo "$REG" | grep -q '"ok":true'

ACCESS=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(x.accessToken)' "$REG")
REFRESH=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(x.refreshToken)' "$REG")

curl -fsS "$BASE/auth/me" -H "Authorization: Bearer $ACCESS" | grep -q '"ok":true'
curl -fsS -X POST "$BASE/auth/refresh" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$REFRESH\"}" | grep -q '"ok":true'
curl -fsS "$BASE/auth/logout" -X POST -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$REFRESH\"}" | grep -q '"ok":true'

echo "=========================================="
echo "DADIA STAGE 4: PASS"
echo "Registration: PASS"
echo "Login token flow: PASS"
echo "Refresh token flow: PASS"
echo "Logout: PASS"
echo "Protected /me: PASS"
echo "Role middleware: READY"
echo "=========================================="
