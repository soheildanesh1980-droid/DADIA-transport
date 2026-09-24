#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
BASE="http://127.0.0.1:3315"
echo "=========================================="
echo "DADIA FULL TEST 1 -> 5"
echo "=========================================="
echo "[1] Stage 1+2"
bash ./test-stage1-2.sh
echo "[2] Stage 3 schema"
set -a; . ./.env; set +a; export PAGER=cat
TABLES=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('users','passenger_profiles','driver_profiles','vehicles','addresses','trips','cargo_orders','payments','trip_locations');")
[ "$TABLES" = "9" ]
echo "Stage 3: PASS"
echo "[3] Health"
curl -fsS "$BASE/health" | grep -q '"status":"ok"'
echo "Stage 4/5 backend health: PASS"
echo "=========================================="
echo "DADIA FULL TEST 1 -> 5: PASS"
echo "=========================================="
