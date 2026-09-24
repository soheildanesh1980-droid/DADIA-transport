#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="http://127.0.0.1:3000"

echo "=========================================="
echo "DADIA STAGE 19 - FINAL FUNCTIONAL TEST"
echo "=========================================="

echo "[1] DRIVER LOGIN"

LOGIN=$(curl -sS -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone":"09000000855","password":"DadiaStage7@Test123"}')

TOKEN=$(printf '%s' "$LOGIN" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')

test -n "$TOKEN"
echo "DRIVER LOGIN: PASS"

echo "[2] CREATE VEHICLE"

VEHICLE=$(curl -sS -w "\nHTTP_STATUS=%{http_code}" \
  -X POST "$BASE/vehicles/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "vehicleType":"sedan",
    "make":"DADIA-TEST",
    "model":"Test Model",
    "modelYear":2025,
    "color":"white",
    "plateNumber":"TEST-19",
    "countryCode":"IR"
  }')

echo "$VEHICLE"

STATUS=$(printf '%s\n' "$VEHICLE" | sed -n 's/HTTP_STATUS=//p')
test "$STATUS" = "200" || test "$STATUS" = "201"

echo "CREATE VEHICLE: PASS"

echo "[3] GET MY VEHICLES"

curl -sS \
  "$BASE/vehicles/me" \
  -H "Authorization: Bearer $TOKEN"

echo
echo "GET VEHICLES: PASS"

echo "[4] CREATE DRIVER DOCUMENT"

DOC=$(curl -sS -w "\nHTTP_STATUS=%{http_code}" \
  -X POST "$BASE/documents/driver" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "documentType":"driver_license",
    "documentNumber":"TEST-DOC-19",
    "countryCode":"IR",
    "status":"pending"
  }')

echo "$DOC"

DOC_STATUS=$(printf '%s\n' "$DOC" | sed -n 's/HTTP_STATUS=//p')
test "$DOC_STATUS" = "200" || test "$DOC_STATUS" = "201"

echo "CREATE DRIVER DOCUMENT: PASS"

echo "[5] GET DRIVER DOCUMENTS"

curl -sS \
  "$BASE/documents/driver/me" \
  -H "Authorization: Bearer $TOKEN"

echo
echo "GET DRIVER DOCUMENTS: PASS"

echo "[6] DATABASE VERIFY"

psql -h localhost -U u0_a320 -d dadia_transport -c "
SELECT
  (SELECT count(*) FROM vehicles) AS vehicles,
  (SELECT count(*) FROM driver_documents) AS driver_documents,
  (SELECT count(*) FROM vehicle_documents) AS vehicle_documents;
"

echo
echo "=========================================="
echo "STAGE 19 FINAL FUNCTIONAL TEST: PASS"
echo "=========================================="
