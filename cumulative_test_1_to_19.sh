#!/data/data/com.termux/files/usr/bin/bash
set -e

BASE="http://127.0.0.1:3000"
PASSENGER_PHONE="09479795217"
PASSENGER_PASS="DadiaTest@123"
DRIVER_PHONE="09000000855"
DRIVER_PASS="DadiaStage7@Test123"
ADMIN_PHONE="09000000789"
ADMIN_PASS="DadiaStage7@Test123"

echo "=========================================="
echo "DADIA CUMULATIVE REAL TEST 1 -> 19"
echo "=========================================="

echo "[1] HEALTH"
curl -fsS "$BASE/health" >/dev/null
echo "PASS"

echo "[2] PASSENGER LOGIN"
PLOGIN=$(curl -fsS -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"phone\":\"$PASSENGER_PHONE\",\"password\":\"$PASSENGER_PASS\"}")
PTOKEN=$(printf '%s' "$PLOGIN" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')
PUSER=$(printf '%s' "$PLOGIN" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
test -n "$PTOKEN"
echo "PASS"

echo "[3] DRIVER LOGIN"
DLOGIN=$(curl -fsS -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"phone\":\"$DRIVER_PHONE\",\"password\":\"$DRIVER_PASS\"}")
DTOKEN=$(printf '%s' "$DLOGIN" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')
DUSER=$(printf '%s' "$DLOGIN" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
test -n "$DTOKEN"
echo "PASS"

echo "[4] ADMIN LOGIN"
ALOGIN=$(curl -fsS -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"phone\":\"$ADMIN_PHONE\",\"password\":\"$ADMIN_PASS\"}")
ATOKEN=$(printf '%s' "$ALOGIN" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')
test -n "$ATOKEN"
echo "PASS"

echo "[5] AUTH ME"
curl -fsS "$BASE/auth/me" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
echo "PASS"

echo "[6] ROLE SECURITY"
test "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/admin/overview" \
  -H "Authorization: Bearer $PTOKEN")" = "403"
echo "PASS"

echo "[7] TRIP TYPES"
curl -fsS "$BASE/trips/types" >/dev/null
echo "PASS"

echo "[8] TRIP ESTIMATE"
EST=$(curl -fsS -X POST "$BASE/trips/estimate" \
  -H "Authorization: Bearer $PTOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "service_type":"ride",
    "vehicle_type":"sedan",
    "origin_lat":35.6892,
    "origin_lng":51.3890,
    "destination_lat":35.7000,
    "destination_lng":51.4100
  }')
echo "$EST" | grep -q '"ok":true'
echo "PASS"

echo "[9] MAP ROUTE ESTIMATE"
curl -fsS -X POST "$BASE/maps/route-estimate" \
  -H "Authorization: Bearer $PTOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "origin":{"latitude":35.6892,"longitude":51.3890},
    "destination":{"latitude":35.7000,"longitude":51.4100}
  }' >/dev/null
echo "PASS"

echo "[10] GLOBAL"
curl -fsS "$BASE/global/countries" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
curl -fsS "$BASE/global/languages" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
echo "PASS"

echo "[11] PRICING"
curl -fsS "$BASE/pricing/currencies" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
curl -fsS -X POST "$BASE/pricing/calculate" \
  -H "Authorization: Bearer $PTOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "serviceType":"ride",
    "vehicleType":"sedan",
    "distanceKm":10,
    "durationMin":20,
    "currency":"IRR"
  }' >/dev/null
echo "PASS"

echo "[12] DRIVER OPERATIONS"
curl -fsS "$BASE/driver/profile" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
curl -fsS "$BASE/driver/status" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
curl -fsS -X POST "$BASE/driver/online" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
echo "PASS"

echo "[13] TRIP CREATE"
TRIP=$(curl -fsS -X POST "$BASE/trips/" \
  -H "Authorization: Bearer $PTOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "origin_address":"DADIA TEST ORIGIN",
    "destination_address":"DADIA TEST DESTINATION",
    "origin_lat":35.6892,
    "origin_lng":51.3890,
    "destination_lat":35.7000,
    "destination_lng":51.4100,
    "service_type":"ride",
    "vehicle_type":"sedan",
    "passenger_note":"DADIA cumulative test"
  }')
TRIP_ID=$(printf '%s' "$TRIP" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
test -n "$TRIP_ID"
echo "PASS"

echo "[14] TRIP ACCESS"
curl -fsS "$BASE/trips/$TRIP_ID" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
curl -fsS "$BASE/passenger/trips/$TRIP_ID" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
echo "PASS"

echo "[15] DRIVER ACCEPT / TRIP FLOW"
curl -fsS -X POST "$BASE/trips/$TRIP_ID/accept" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
curl -fsS -X POST "$BASE/trips/$TRIP_ID/arrive" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
curl -fsS -X POST "$BASE/trips/$TRIP_ID/start" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
echo "PASS"

echo "[16] TRACKING"
curl -fsS "$BASE/trips/$TRIP_ID/tracking" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
echo "PASS"

echo "[17] DRIVER LOCATION"
curl -fsS -X POST "$BASE/driver/location" \
  -H "Authorization: Bearer $DTOKEN" \
  -H "Content-Type: application/json" \
  -d '{"latitude":35.7000,"longitude":51.4100}' >/dev/null
curl -fsS "$BASE/driver/location/current" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
echo "PASS"

echo "[18] COMPLETE TRIP"
curl -fsS -X POST "$BASE/trips/$TRIP_ID/complete" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
echo "PASS"

echo "[19] PAYMENT"
PAY=$(curl -fsS -X POST "$BASE/payment/create" \
  -H "Authorization: Bearer $PTOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount":1200000,
    "currency":"IRR",
    "description":"DADIA cumulative test"
  }')
PAY_ID=$(printf '%s' "$PAY" | sed -n 's/.*"payment":{"paymentId":"\([^"]*\)".*/\1/p')
test -n "$PAY_ID"
curl -fsS -X POST "$BASE/payment/$PAY_ID/verify" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
echo "PASS"

echo "[20] EARNINGS"
curl -fsS -X POST "$BASE/earnings/earning" \
  -H "Authorization: Bearer $DTOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"tripId\":\"$TRIP_ID\",\"grossAmount\":1200000,\"platformFee\":100000,\"currency\":\"IRR\",\"description\":\"DADIA cumulative test\"}" >/dev/null
curl -fsS "$BASE/earnings/me" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
echo "PASS"

echo "[21] NOTIFICATIONS"
NOTIF=$(curl -fsS -X POST "$BASE/notifications/" \
  -H "Authorization: Bearer $PTOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "channel":"in_app",
    "title":"DADIA TEST",
    "message":"Cumulative test"
  }')
NOTIF_ID=$(printf '%s' "$NOTIF" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
test -n "$NOTIF_ID"
curl -fsS -X POST "$BASE/notifications/$NOTIF_ID/read" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
echo "PASS"

echo "[22] RATING"
curl -fsS -X POST "$BASE/rating/" \
  -H "Authorization: Bearer $PTOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"ratedUserId\":\"$DUSER\",\"tripId\":\"$TRIP_ID\",\"score\":5,\"comment\":\"DADIA test\"}" >/dev/null
curl -fsS "$BASE/rating/me" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
echo "PASS"

echo "[23] SUPPORT"
curl -fsS -X POST "$BASE/support/" \
  -H "Authorization: Bearer $PTOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "subject":"DADIA cumulative test",
    "message":"Cumulative functional test",
    "priority":"normal"
  }' >/dev/null
curl -fsS "$BASE/support/me" \
  -H "Authorization: Bearer $PTOKEN" >/dev/null
echo "PASS"

echo "[24] VEHICLES + DOCUMENTS"
curl -fsS "$BASE/vehicles/me" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
curl -fsS "$BASE/documents/driver/me" \
  -H "Authorization: Bearer $DTOKEN" >/dev/null
echo "PASS"

echo "[25] DATABASE"
psql -h localhost -U u0_a320 -d dadia_transport -c "SELECT 1;" >/dev/null

echo "[26] REDIS"
redis-cli ping | grep -q PONG

echo "[27] BUILD"
npm run build >/dev/null

echo "=========================================="
echo "DADIA CUMULATIVE TEST 1 -> 19: PASS"
echo "=========================================="
