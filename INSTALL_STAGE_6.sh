#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=========================================="
echo "DADIA STAGE 6 INSTALL"
echo "=========================================="

ROOT="$HOME/DADIA-Transport"
cd "$ROOT"

echo "[1/7] BACKUP"
BACKUP="BACKUP_BEFORE_STAGE_6_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"
cp -r src package.json tsconfig.json "$BACKUP/" 2>/dev/null || true

echo "[2/7] CHECK CURRENT PROJECT"
test -d src
test -f package.json
test -f tsconfig.json

echo "[3/7] CHECK DEPENDENCIES"
npm install

echo "[4/7] TYPECHECK"
npm run typecheck

echo "[5/7] BUILD"
npm run build

echo "[6/7] RUN FULL TEST 1 -> 5"
test -x ./FULL_TEST_1_TO_5.sh
./FULL_TEST_1_TO_5.sh

echo "[7/7] STAGE 6 INSTALL RESULT"
echo "=========================================="
echo "DADIA STAGE 6 INSTALL: PASS"
echo "=========================================="
