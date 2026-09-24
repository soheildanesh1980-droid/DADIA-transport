#!/data/data/com.termux/files/usr/bin/bash

set -e

BASE="http://127.0.0.1:3000"

echo "=========================================="
echo "STAGE 23 FINAL FUNCTIONAL TEST"
echo "=========================================="

echo "=== REDIS ==="
redis-cli ping | grep -q PONG
echo "REDIS: PASS"

echo "=== HEALTH ==="
curl -sS "$BASE/health" | grep -q '"status":"ok"'
echo "HEALTH: PASS"

echo "=== LOGIN ==="

LOGIN=$(curl -sS -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone":"09479795217","password":"DadiaTest@123"}')

TOKEN=$(printf '%s' "$LOGIN" |
  sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')

[ -n "$TOKEN" ]
echo "LOGIN: PASS"

echo "=== CREATE HEAVY TRUCK ORDER ==="

ORDER=$(curl -sS -X POST "$BASE/heavy-truck/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "originAddress":"تهران، میدان آزادی",
    "destinationAddress":"تهران، بندرعباس",
    "originLat":35.6892,
    "originLng":51.3890,
    "destinationLat":27.1832,
    "destinationLng":56.2666,
    "cargoType":"بار عمومی",
    "cargoDescription":"تست حمل بار سنگین Stage 23",
    "weightTon":12.5,
    "volumeM3":45,
    "vehicleType":"truck",
    "truckType":"تریلی",
    "axleCount":6,
    "requiresTrailer":true,
    "trailerType":"کفی",
    "loadingType":"بارگیری از مبدا",
    "specialRequirements":"تست Stage 23",
    "recipientName":"گیرنده تست",
    "recipientPhone":"09120000000",
    "passengerPhone":"09479795217",
    "countryCode":"IR",
    "currency":"IRR"
  }')

printf '%s' "$ORDER" | grep -q '"ok":true'

ORDER_ID=$(printf '%s' "$ORDER" |
  sed -n 's/.*"order":{"id":"\([^"]*\)".*/\1/p')

[ -n "$ORDER_ID" ]

echo "CREATE ORDER: PASS"
echo "ORDER_ID=$ORDER_ID"

echo "=== GET MY ORDERS ==="

MY_ORDERS=$(curl -sS "$BASE/heavy-truck/me" \
  -H "Authorization: Bearer $TOKEN")

printf '%s' "$MY_ORDERS" | grep -q "$ORDER_ID"

echo "GET ORDERS: PASS"

echo "=== DATABASE ==="

DB_MATCH=$(psql -h localhost -U u0_a320 \
  -d dadia_transport -tAc \
  "SELECT COUNT(*)
     FROM heavy_truck_orders
    WHERE id='$ORDER_ID'
      AND weight_ton=12.5
      AND axle_count=6
      AND requires_trailer=true
      AND country_code='IR'
      AND currency='IRR'
      AND status='requested';" | tr -d ' ')

echo "DB_MATCH=$DB_MATCH"

[ "$DB_MATCH" = "1" ]

echo "DATABASE VERIFY: PASS"

echo "=== INVALID WEIGHT ==="

HTTP=$(curl -sS -o /dev/null -w "%{http_code}" \
  -X POST "$BASE/heavy-truck/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "originAddress":"تهران",
    "destinationAddress":"قم",
    "originLat":35.6892,
    "originLng":51.3890,
    "destinationLat":34.6416,
    "destinationLng":50.8746,
    "weightTon":-5
  }')

echo "HTTP=$HTTP"
[ "$HTTP" = "400" ]

echo "INVALID WEIGHT: PASS"

echo "=== INVALID AXLE COUNT ==="

HTTP=$(curl -sS -o /dev/null -w "%{http_code}" \
  -X POST "$BASE/heavy-truck/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "originAddress":"تهران",
    "destinationAddress":"قم",
    "originLat":35.6892,
    "originLng":51.3890,
    "destinationLat":34.6416,
    "destinationLng":50.8746,
    "weightTon":5,
    "axleCount":0
  }')

echo "HTTP=$HTTP"
[ "$HTTP" = "400" ]

echo "INVALID AXLE COUNT: PASS"

echo "=== AUTH SECURITY ==="

HTTP=$(curl -sS -o /dev/null -w "%{http_code}" \
  -X POST "$BASE/heavy-truck/" \
  -H "Content-Type: application/json" \
  -d '{
    "originAddress":"تهران",
    "destinationAddress":"قم",
    "originLat":35.6892,
    "originLng":51.3890,
    "destinationLat":34.6416,
    "destinationLng":50.8746
  }')

echo "HTTP=$HTTP"
[ "$HTTP" = "401" ]

echo "AUTH SECURITY: PASS"

echo "=== BUILD ==="

npm run build

echo "BUILD: PASS"

echo "=========================================="
echo "STAGE 23 FUNCTIONAL TEST: PASS"
echo "=========================================="
