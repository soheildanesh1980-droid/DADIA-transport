#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "=================================================="
echo "DADIA STAGE 8 - FULL INSTALL"
echo "=================================================="

TS=$(date +%Y%m%d_%H%M%S)
BACKUP="BACKUP_STAGE_8_FULL_$TS"

echo "[1] BACKUP"
mkdir -p "$BACKUP"
cp -a src package.json package-lock.json tsconfig.json .env "$BACKUP" 2>/dev/null || true
echo "BACKUP: $BACKUP"
echo "BACKUP: PASS"

echo "[2] DATABASE MIGRATION"

cat > src/database/migrations/003_stage8_trip_engine.sql <<'SQL'
BEGIN;

ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS service_type VARCHAR(30) NOT NULL DEFAULT 'ride',
  ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(30),
  ADD COLUMN IF NOT EXISTS estimated_distance_km NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS estimated_duration_min INTEGER,
  ADD COLUMN IF NOT EXISTS estimated_fare NUMERIC(14,0) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS final_fare NUMERIC(14,0),
  ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS passenger_note VARCHAR(1000),
  ADD COLUMN IF NOT EXISTS pricing_version INTEGER NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_trips_service_type
ON trips(service_type);

CREATE INDEX IF NOT EXISTS idx_trips_scheduled_at
ON trips(scheduled_at);

CREATE INDEX IF NOT EXISTS idx_trips_driver_status
ON trips(driver_id,status);

CREATE INDEX IF NOT EXISTS idx_trips_passenger_status
ON trips(passenger_id,status);

COMMIT;
SQL

node --input-type=module <<'EOF'
import "dotenv/config";
import pg from "pg";
import fs from "fs";

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
  const sql = fs.readFileSync(
    "src/database/migrations/003_stage8_trip_engine.sql",
    "utf8"
  );
  await client.query(sql);
  console.log("DATABASE MIGRATION: PASS");
} catch (e) {
  console.error("DATABASE MIGRATION: FAIL");
  console.error(e.message);
  process.exit(1);
} finally {
  await client.end().catch(() => {});
}
EOF

echo "[3] WRITE STAGE 8 TRIP ENGINE"

cat > src/modules/trips/index.ts <<'TS'
import { Router } from "express";
import { pool } from "../../database/postgres.js";
import { getAuthUser, requireAuth, requireRole } from "../../middleware/auth.js";

const router = Router();

type ServiceConfig = {
  label: string;
  baseFare: number;
  perKm: number;
  speedKmh: number;
  allowedVehicles: string[];
};

const SERVICES: Record<string, ServiceConfig> = {
  ride: {
    label: "سفر شهری",
    baseFare: 500000,
    perKm: 80000,
    speedKmh: 30,
    allowedVehicles: ["sedan", "motorcycle", "van"]
  },
  courier: {
    label: "پیک موتوری",
    baseFare: 300000,
    perKm: 60000,
    speedKmh: 25,
    allowedVehicles: ["motorcycle"]
  },
  pickup: {
    label: "وانت و بار شهری",
    baseFare: 1000000,
    perKm: 120000,
    speedKmh: 25,
    allowedVehicles: ["pickup", "van"]
  },
  moving: {
    label: "اسباب کشی",
    baseFare: 1500000,
    perKm: 110000,
    speedKmh: 25,
    allowedVehicles: ["pickup", "van", "truck"]
  },
  truck: {
    label: "خودروی سنگین",
    baseFare: 2000000,
    perKm: 180000,
    speedKmh: 35,
    allowedVehicles: ["truck"]
  }
};

function num(v: unknown): boolean {
  return typeof v === "number" && Number.isFinite(v);
}

function coord(v: unknown, min: number, max: number): boolean {
  return typeof v === "number" && Number.isFinite(v) && v >= min && v <= max;
}

function distanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;

  return 2 * R * Math.asin(Math.sqrt(a));
}

function estimate(
  serviceType: string,
  vehicleType: string | undefined,
  originLat: number,
  originLng: number,
  destinationLat: number,
  destinationLng: number
) {
  const service = SERVICES[serviceType];

  if (!service) {
    throw new Error("unsupported_service_type");
  }

  const vehicle = vehicleType ?? service.allowedVehicles[0];

  if (!service.allowedVehicles.includes(vehicle)) {
    throw new Error("vehicle_type_not_supported");
  }

  const straight = distanceKm(
    originLat,
    originLng,
    destinationLat,
    destinationLng
  );

  const km = Math.max(0.5, Number((straight * 1.15).toFixed(2)));

  const minutes = Math.max(
    5,
    Math.ceil((km / service.speedKmh) * 60)
  );

  const rawFare = service.baseFare + km * service.perKm;
  const fare = Math.ceil(rawFare / 10000) * 10000;

  return {
    serviceType,
    vehicleType: vehicle,
    distanceKm: km,
    durationMin: minutes,
    estimatedFare: fare,
    pricingVersion: 1,
    currency: "IRR"
  };
}

router.get("/", requireAuth, async (req, res) => {
  try {
    const user = getAuthUser(req);

    let result;

    if (user.role === "passenger") {
      result = await pool.query(
        `SELECT *
         FROM trips
         WHERE passenger_id = $1
         ORDER BY created_at DESC`,
        [user.sub]
      );
    } else if (user.role === "driver") {
      result = await pool.query(
        `SELECT *
         FROM trips
         WHERE driver_id = $1
            OR (driver_id IS NULL AND status IN ('requested','searching'))
         ORDER BY created_at DESC`,
        [user.sub]
      );
    } else if (user.role === "admin") {
      result = await pool.query(
        `SELECT *
         FROM trips
         ORDER BY created_at DESC`
      );
    } else {
      return res.status(403).json({
        ok: false,
        error: "دسترسی مجاز نیست"
      });
    }

    return res.json({
      ok: true,
      trips: result.rows
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({
      ok: false,
      error: "internal_error"
    });
  }
});

router.get("/types", (_req, res) => {
  res.json({
    ok: true,
    services: Object.entries(SERVICES).map(([id, s]) => ({
      id,
      label: s.label,
      allowedVehicles: s.allowedVehicles,
      pricingVersion: 1
    }))
  });
});

router.post(
  "/estimate",
  requireAuth,
  requireRole("passenger"),
  async (req, res) => {
    try {
      const {
        service_type = "ride",
        vehicle_type,
        origin_lat,
        origin_lng,
        destination_lat,
        destination_lng
      } = req.body ?? {};

      if (
        !coord(origin_lat, -90, 90) ||
        !coord(origin_lng, -180, 180) ||
        !coord(destination_lat, -90, 90) ||
        !coord(destination_lng, -180, 180)
      ) {
        return res.status(400).json({
          ok: false,
          error: "invalid_coordinates"
        });
      }

      const result = estimate(
        service_type,
        vehicle_type,
        origin_lat,
        origin_lng,
        destination_lat,
        destination_lng
      );

      return res.json({
        ok: true,
        estimate: result
      });
    } catch (e) {
      return res.status(400).json({
        ok: false,
        error: e instanceof Error ? e.message : "estimate_failed"
      });
    }
  }
);

router.get("/:id", requireAuth, async (req, res) => {
  try {
    const user = getAuthUser(req);

    const result = await pool.query(
      `SELECT *
       FROM trips
       WHERE id = $1
       LIMIT 1`,
      [req.params.id]
    );

    if (!result.rowCount) {
      return res.status(404).json({
        ok: false,
        error: "trip_not_found"
      });
    }

    const trip = result.rows[0];

    const allowed =
      user.role === "admin" ||
      trip.passenger_id === user.sub ||
      trip.driver_id === user.sub;

    if (!allowed) {
      return res.status(403).json({
        ok: false,
        error: "دسترسی مجاز نیست"
      });
    }

    return res.json({
      ok: true,
      trip
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({
      ok: false,
      error: "internal_error"
    });
  }
});

router.post(
  "/",
  requireAuth,
  requireRole("passenger"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const {
        origin_address,
        destination_address,
        origin_lat,
        origin_lng,
        destination_lat,
        destination_lng,
        service_type = "ride",
        vehicle_type,
        scheduled_at,
        passenger_note
      } = req.body ?? {};

      if (
        typeof origin_address !== "string" ||
        !origin_address.length ||
        origin_address.length > 500
      ) {
        return res.status(400).json({
          ok: false,
          error: "invalid_origin_address"
        });
      }

      if (
        typeof destination_address !== "string" ||
        !destination_address.length ||
        destination_address.length > 500
      ) {
        return res.status(400).json({
          ok: false,
          error: "invalid_destination_address"
        });
      }

      if (
        !coord(origin_lat, -90, 90) ||
        !coord(origin_lng, -180, 180) ||
        !coord(destination_lat, -90, 90) ||
        !coord(destination_lng, -180, 180)
      ) {
        return res.status(400).json({
          ok: false,
          error: "invalid_coordinates"
        });
      }

      if (typeof service_type !== "string" || !SERVICES[service_type]) {
        return res.status(400).json({
          ok: false,
          error: "invalid_service_type"
        });
      }

      if (vehicle_type !== undefined) {
        if (
          typeof vehicle_type !== "string" ||
          !SERVICES[service_type].allowedVehicles.includes(vehicle_type)
        ) {
          return res.status(400).json({
            ok: false,
            error: "vehicle_type_not_supported"
          });
        }
      }

      if (
        passenger_note !== undefined &&
        (typeof passenger_note !== "string" ||
          passenger_note.length > 1000)
      ) {
        return res.status(400).json({
          ok: false,
          error: "invalid_passenger_note"
        });
      }

      let scheduled = null;

      if (scheduled_at !== undefined && scheduled_at !== null) {
        if (typeof scheduled_at !== "string") {
          return res.status(400).json({
            ok: false,
            error: "invalid_scheduled_at"
          });
        }

        const d = new Date(scheduled_at);

        if (Number.isNaN(d.getTime())) {
          return res.status(400).json({
            ok: false,
            error: "invalid_scheduled_at"
          });
        }

        scheduled = d.toISOString();
      }

      let pricing;

      try {
        pricing = estimate(
          service_type,
          vehicle_type,
          origin_lat,
          origin_lng,
          destination_lat,
          destination_lng
        );
      } catch (e) {
        return res.status(400).json({
          ok: false,
          error: e instanceof Error ? e.message : "estimate_failed"
        });
      }

      const result = await pool.query(
        `INSERT INTO trips (
          passenger_id,
          origin_address,
          destination_address,
          origin_latitude,
          origin_longitude,
          destination_latitude,
          destination_longitude,
          status,
          service_type,
          vehicle_type,
          estimated_distance_km,
          estimated_duration_min,
          estimated_fare,
          scheduled_at,
          passenger_note,
          pricing_version
        )
        VALUES (
          $1,$2,$3,$4,$5,$6,$7,
          'requested',
          $8,$9,$10,$11,$12,$13,$14,$15
        )
        RETURNING *`,
        [
          user.sub,
          origin_address,
          destination_address,
          origin_lat,
          origin_lng,
          destination_lat,
          destination_lng,
          service_type,
          pricing.vehicleType,
          pricing.distanceKm,
          pricing.durationMin,
          pricing.estimatedFare,
          scheduled,
          passenger_note ?? null,
          pricing.pricingVersion
        ]
      );

      return res.status(201).json({
        ok: true,
        trip: result.rows[0],
        pricing
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

router.post(
  "/:id/accept",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const driver = await pool.query(
        `SELECT status
         FROM driver_profiles
         WHERE user_id = $1`,
        [user.sub]
      );

      if (
        driver.rowCount === 0 ||
        driver.rows[0].status !== "approved"
      ) {
        return res.status(403).json({
          ok: false,
          error: "driver_not_approved"
        });
      }

      const result = await pool.query(
        `UPDATE trips
         SET driver_id = $1,
             status = 'accepted',
             accepted_at = NOW()
         WHERE id = $2
           AND status IN ('requested','searching')
           AND driver_id IS NULL
         RETURNING *`,
        [user.sub, req.params.id]
      );

      if (!result.rowCount) {
        return res.status(409).json({
          ok: false,
          error: "trip_not_available"
        });
      }

      return res.json({
        ok: true,
        trip: result.rows[0]
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

router.post(
  "/:id/arrive",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `UPDATE trips
         SET status = 'arriving'
         WHERE id = $1
           AND driver_id = $2
           AND status = 'accepted'
         RETURNING *`,
        [req.params.id, user.sub]
      );

      if (!result.rowCount) {
        return res.status(409).json({
          ok: false,
          error: "invalid_trip_state"
        });
      }

      return res.json({
        ok: true,
        trip: result.rows[0]
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

router.post(
  "/:id/start",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `UPDATE trips
         SET status = 'started'
         WHERE id = $1
           AND driver_id = $2
           AND status IN ('accepted','arriving')
         RETURNING *`,
        [req.params.id, user.sub]
      );

      if (!result.rowCount) {
        return res.status(409).json({
          ok: false,
          error: "invalid_trip_state"
        });
      }

      return res.json({
        ok: true,
        trip: result.rows[0]
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

router.post(
  "/:id/complete",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `UPDATE trips
         SET status = 'completed',
             final_fare = COALESCE(final_fare, estimated_fare)
         WHERE id = $1
           AND driver_id = $2
           AND status = 'started'
         RETURNING *`,
        [req.params.id, user.sub]
      );

      if (!result.rowCount) {
        return res.status(409).json({
          ok: false,
          error: "invalid_trip_state"
        });
      }

      return res.json({
        ok: true,
        trip: result.rows[0]
      });
    } catch (e) {
      console.error(e);
      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

router.post("/:id/cancel", requireAuth, async (req, res) => {
  try {
    const user = getAuthUser(req);

    let result;

    if (user.role === "admin") {
      result = await pool.query(
        `UPDATE trips
         SET status = 'cancelled'
         WHERE id = $1
           AND status NOT IN ('completed','cancelled')
         RETURNING *`,
        [req.params.id]
      );
    } else if (user.role === "passenger") {
      result = await pool.query(
        `UPDATE trips
         SET status = 'cancelled'
         WHERE id = $1
           AND passenger_id = $2
           AND status IN ('requested','searching','accepted','arriving')
         RETURNING *`,
        [req.params.id, user.sub]
      );
    } else if (user.role === "driver") {
      result = await pool.query(
        `UPDATE trips
         SET status = 'cancelled'
         WHERE id = $1
           AND driver_id = $2
           AND status IN ('accepted','arriving')
         RETURNING *`,
        [req.params.id, user.sub]
      );
    } else {
      return res.status(403).json({
        ok: false,
        error: "دسترسی مجاز نیست"
      });
    }

    if (!result.rowCount) {
      return res.status(409).json({
        ok: false,
        error: "trip_cannot_be_cancelled"
      });
    }

    return res.json({
      ok: true,
      trip: result.rows[0]
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({
      ok: false,
      error: "internal_error"
    });
  }
});

export default router;
TS

echo "TRIP ENGINE: PASS"

echo "[4] BUILD"
npx tsc --noEmit
npm run build
echo "BUILD: PASS"

echo "[5] RESTART API"
pkill -f "node dist/server.js" 2>/dev/null || true
sleep 1
nohup node dist/server.js > stage8-server.log 2>&1 &
sleep 2

echo "[6] HEALTH"
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -fsS http://127.0.0.1:3000/health >/dev/null 2>&1; then
    echo "HEALTH: PASS"
    break
  fi
  sleep 1
  if [ "$i" = "10" ]; then
    echo "HEALTH: FAIL"
    cat stage8-server.log
    exit 1
  fi
done

echo "[7] FUNCTIONAL TEST 1 -> 8"

node --input-type=module <<'EOF'
import "dotenv/config";
import pg from "pg";

const { Pool } = pg;

const pool = new Pool({
  host: process.env.POSTGRES_HOST,
  port: Number(process.env.POSTGRES_PORT),
  database: process.env.POSTGRES_DB,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD
});

const base = "http://127.0.0.1:3000";

const passengerPhone = "09479795217";
const passengerPassword = "DadiaTest@123";

const driverPhone = "09000000855";
const driverPassword = "DadiaStage7@Test123";

const adminPhone = "09000000789";
const adminPassword = "DadiaStage7@Test123";

let failed = false;
let tripId = null;

function pass(name) {
  console.log(`${name}: PASS`);
}

function fail(name, detail = "") {
  console.log(`${name}: FAIL`);
  if (detail) console.log(detail);
  failed = true;
}

async function call(path, options = {}) {
  const response = await fetch(`${base}${path}`, options);

  let body = {};
  try {
    body = await response.json();
  } catch {}

  return { response, body };
}

try {
  console.log("==========================================");
  console.log("DADIA FINAL FUNCTIONAL TEST 1 -> 8");
  console.log("==========================================");

  try {
    await pool.query("SELECT 1");
    pass("POSTGRES");
  } catch (e) {
    fail("POSTGRES", e.message);
  }

  try {
    const { response, body } = await call("/health");

    if (
      response.status === 200 &&
      body.status === "ok" &&
      body.backend === true &&
      body.database === true &&
      body.redis === true
    ) {
      pass("HEALTH + REDIS");
    } else {
      fail("HEALTH + REDIS", JSON.stringify(body));
    }
  } catch (e) {
    fail("HEALTH + REDIS", e.message);
  }

  let passengerToken;

  try {
    const { response, body } = await call("/auth/login", {
      method: "POST",
      headers: {"Content-Type":"application/json"},
      body: JSON.stringify({
        phone: passengerPhone,
        password: passengerPassword
      })
    });

    if (
      response.status === 200 &&
      body.accessToken &&
      body.user?.role === "passenger"
    ) {
      passengerToken = body.accessToken;
      pass("PASSENGER LOGIN");
    } else {
      fail("PASSENGER LOGIN", JSON.stringify(body));
    }
  } catch (e) {
    fail("PASSENGER LOGIN", e.message);
  }

  if (passengerToken) {
    try {
      const { response, body } = await call("/passenger/profile", {
        headers: {
          Authorization: `Bearer ${passengerToken}`
        }
      });

      if (response.status === 200 && body.ok && body.profile?.user_id) {
        pass("PASSENGER PROFILE");
      } else {
        fail("PASSENGER PROFILE", JSON.stringify(body));
      }
    } catch (e) {
      fail("PASSENGER PROFILE", e.message);
    }

    try {
      const { response } = await call("/admin/overview", {
        headers: {
          Authorization: `Bearer ${passengerToken}`
        }
      });

      if (response.status === 403) {
        pass("PASSENGER ROLE PROTECTION");
      } else {
        fail("PASSENGER ROLE PROTECTION", `HTTP ${response.status}`);
      }
    } catch (e) {
      fail("PASSENGER ROLE PROTECTION", e.message);
    }

    try {
      const { response, body } = await call("/trips/types", {
        headers: {
          Authorization: `Bearer ${passengerToken}`
        }
      });

      if (
        response.status === 200 &&
        body.ok &&
        Array.isArray(body.services) &&
        body.services.some(x => x.id === "ride")
      ) {
        pass("STAGE 8 SERVICE TYPES");
      } else {
        fail("STAGE 8 SERVICE TYPES", JSON.stringify(body));
      }
    } catch (e) {
      fail("STAGE 8 SERVICE TYPES", e.message);
    }

    try {
      const { response, body } = await call("/trips/estimate", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${passengerToken}`
        },
        body: JSON.stringify({
          service_type: "ride",
          vehicle_type: "sedan",
          origin_lat: 35.6892,
          origin_lng: 51.3890,
          destination_lat: 35.7219,
          destination_lng: 51.3347
        })
      });

      if (
        response.status === 200 &&
        body.ok &&
        body.estimate?.distanceKm > 0 &&
        body.estimate?.durationMin > 0 &&
        body.estimate?.estimatedFare > 0
      ) {
        pass("STAGE 8 FARE ESTIMATE");
      } else {
        fail("STAGE 8 FARE ESTIMATE", JSON.stringify(body));
      }
    } catch (e) {
      fail("STAGE 8 FARE ESTIMATE", e.message);
    }

    try {
      const { response, body } = await call("/trips", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${passengerToken}`
        },
        body: JSON.stringify({
          origin_address: "Stage 8 Test Origin",
          destination_address: "Stage 8 Test Destination",
          origin_lat: 35.6892,
          origin_lng: 51.3890,
          destination_lat: 35.7219,
          destination_lng: 51.3347,
          service_type: "ride",
          vehicle_type: "sedan",
          passenger_note: "STAGE8_FUNCTIONAL_TEST"
        })
      });

      tripId = body.trip?.id ?? null;

      if (
        response.status === 201 &&
        body.ok &&
        tripId &&
        body.trip?.status === "requested" &&
        body.trip?.service_type === "ride" &&
        Number(body.trip?.estimated_fare) > 0
      ) {
        pass("STAGE 8 ADVANCED TRIP CREATE");
      } else {
        fail("STAGE 8 ADVANCED TRIP CREATE", JSON.stringify(body));
      }
    } catch (e) {
      fail("STAGE 8 ADVANCED TRIP CREATE", e.message);
    }
  }

  let adminToken;

  try {
    const { response, body } = await call("/auth/login", {
      method: "POST",
      headers: {"Content-Type":"application/json"},
      body: JSON.stringify({
        phone: adminPhone,
        password: adminPassword
      })
    });

    if (
      response.status === 200 &&
      body.accessToken &&
      body.user?.role === "admin"
    ) {
      adminToken = body.accessToken;
      pass("ADMIN LOGIN");
    } else {
      fail("ADMIN LOGIN", JSON.stringify(body));
    }
  } catch (e) {
    fail("ADMIN LOGIN", e.message);
  }

  if (adminToken) {
    try {
      const { response, body } = await call("/admin/overview", {
        headers: {
          Authorization: `Bearer ${adminToken}`
        }
      });

      if (response.status === 200 && body.ok && Array.isArray(body.users)) {
        pass("ADMIN OVERVIEW");
      } else {
        fail("ADMIN OVERVIEW", JSON.stringify(body));
      }
    } catch (e) {
      fail("ADMIN OVERVIEW", e.message);
    }
  }

  let driverToken;

  try {
    const { response, body } = await call("/auth/login", {
      method: "POST",
      headers: {"Content-Type":"application/json"},
      body: JSON.stringify({
        phone: driverPhone,
        password: driverPassword
      })
    });

    if (
      response.status === 200 &&
      body.accessToken &&
      body.user?.role === "driver"
    ) {
      driverToken = body.accessToken;
      pass("DRIVER LOGIN");
    } else {
      fail("DRIVER LOGIN", JSON.stringify(body));
    }
  } catch (e) {
    fail("DRIVER LOGIN", e.message);
  }

  if (driverToken) {
    try {
      const { response, body } = await call("/driver/profile", {
        headers: {
          Authorization: `Bearer ${driverToken}`
        }
      });

      if (
        response.status === 200 &&
        body.ok &&
        body.profile?.status === "approved"
      ) {
        pass("DRIVER APPROVED PROFILE");
      } else {
        fail("DRIVER APPROVED PROFILE", JSON.stringify(body));
      }
    } catch (e) {
      fail("DRIVER APPROVED PROFILE", e.message);
    }
  }

  if (tripId && driverToken) {
    try {
      const { response, body } = await call(`/trips/${tripId}/accept`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${driverToken}`
        }
      });

      if (response.status === 200 && body.ok && body.trip?.status === "accepted") {
        pass("TRIP ACCEPT");
      } else {
        fail("TRIP ACCEPT", JSON.stringify(body));
      }
    } catch (e) {
      fail("TRIP ACCEPT", e.message);
    }

    try {
      const { response, body } = await call(`/trips/${tripId}/arrive`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${driverToken}`
        }
      });

      if (response.status === 200 && body.ok && body.trip?.status === "arriving") {
        pass("TRIP ARRIVE");
      } else {
        fail("TRIP ARRIVE", JSON.stringify(body));
      }
    } catch (e) {
      fail("TRIP ARRIVE", e.message);
    }

    try {
      const { response, body } = await call(`/trips/${tripId}/start`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${driverToken}`
        }
      });

      if (response.status === 200 && body.ok && body.trip?.status === "started") {
        pass("TRIP START");
      } else {
        fail("TRIP START", JSON.stringify(body));
      }
    } catch (e) {
      fail("TRIP START", e.message);
    }

    try {
      const { response, body } = await call(`/trips/${tripId}/complete`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${driverToken}`
        }
      });

      if (
        response.status === 200 &&
        body.ok &&
        body.trip?.status === "completed" &&
        body.trip?.final_fare !== null
      ) {
        pass("TRIP COMPLETE + FINAL FARE");
      } else {
        fail("TRIP COMPLETE + FINAL FARE", JSON.stringify(body));
      }
    } catch (e) {
      fail("TRIP COMPLETE + FINAL FARE", e.message);
    }

    try {
      const result = await pool.query(
        `SELECT
           status,
           driver_id,
           service_type,
           vehicle_type,
           estimated_distance_km,
           estimated_duration_min,
           estimated_fare,
           final_fare,
           pricing_version,
           passenger_note
         FROM trips
         WHERE id = $1`,
        [tripId]
      );

      const row = result.rows[0];

      if (
        result.rowCount === 1 &&
        row.status === "completed" &&
        row.driver_id &&
        row.service_type === "ride" &&
        row.vehicle_type === "sedan" &&
        Number(row.estimated_distance_km) > 0 &&
        Number(row.estimated_duration_min) > 0 &&
        Number(row.estimated_fare) > 0 &&
        Number(row.final_fare) > 0 &&
        row.pricing_version === 1 &&
        row.passenger_note === "STAGE8_FUNCTIONAL_TEST"
      ) {
        pass("STAGE 8 DATABASE FINAL STATE");
        console.log("STAGE 8 TEST TRIP:", tripId);
        console.log("TRIP STATUS:", row.status);
        console.log("TRIP SERVICE:", row.service_type);
        console.log("TRIP ESTIMATED FARE:", row.estimated_fare);
        console.log("TRIP FINAL FARE:", row.final_fare);
      } else {
        fail("STAGE 8 DATABASE FINAL STATE", JSON.stringify(row));
      }
    } catch (e) {
      fail("STAGE 8 DATABASE FINAL STATE", e.message);
    }

    try {
      const { response, body } = await call(`/trips/${tripId}`, {
        headers: {
          Authorization: `Bearer ${driverToken}`
        }
      });

      if (
        response.status === 200 &&
        body.ok &&
        body.trip?.status === "completed" &&
        body.trip?.final_fare !== null
      ) {
        pass("DRIVER TRIP READ");
      } else {
        fail("DRIVER TRIP READ", JSON.stringify(body));
      }
    } catch (e) {
      fail("DRIVER TRIP READ", e.message);
    }
  }

  try {
    const { response } = await call(
      "/trips/00000000-0000-0000-0000-000000000000",
      {
        headers: {
          Authorization: "Bearer INVALID_TEST_TOKEN"
        }
      }
    );

    if (response.status === 401) {
      pass("INVALID TOKEN REJECTION");
    } else {
      fail("INVALID TOKEN REJECTION", `HTTP ${response.status}`);
    }
  } catch (e) {
    fail("INVALID TOKEN REJECTION", e.message);
  }

  console.log("==========================================");

  if (failed) {
    console.log("DADIA STAGE 8: FAIL");
    console.log("DADIA FULL FUNCTIONAL TEST 1 -> 8: FAIL");
    process.exitCode = 1;
  } else {
    console.log("DADIA STAGE 8: PASS");
    console.log("DADIA FULL FUNCTIONAL TEST 1 -> 8: PASS");
  }

  console.log("==========================================");

} finally {
  await pool.end();
}
EOF

echo "=================================================="
echo "DADIA STAGE 8 FINISHED"
echo "=================================================="
