#!/data/data/com.termux/files/usr/bin/bash
set -e

cd ~/DADIA-Transport

echo "=================================================="
echo "DADIA STAGE 9 - FULL INSTALL"
echo "=================================================="

TS=$(date +%Y%m%d_%H%M%S)
BACKUP="BACKUP_STAGE_9_FULL_${TS}"

echo "[1] BACKUP"
mkdir -p "$BACKUP"
cp -a src package.json package-lock.json tsconfig.json .env "$BACKUP/" 2>/dev/null || true
echo "BACKUP: $BACKUP"
echo "BACKUP: PASS"

echo "[2] DATABASE MIGRATION"

mkdir -p src/database/migrations

cat > src/database/migrations/004_stage9_driver_operations.sql <<'SQL'
ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS availability_status VARCHAR(20) NOT NULL DEFAULT 'offline';

ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS last_online_at TIMESTAMPTZ;

ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS last_offline_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_driver_profiles_availability
  ON driver_profiles(availability_status);

CREATE INDEX IF NOT EXISTS idx_driver_profiles_status_availability
  ON driver_profiles(status, availability_status);
SQL

node --input-type=module <<'NODE'
import "dotenv/config";
import { pool } from "./dist/database/postgres.js";

const fs = await import("fs/promises");
const sql = await fs.readFile(
  "src/database/migrations/004_stage9_driver_operations.sql",
  "utf8"
);

await pool.query(sql);
console.log("DATABASE MIGRATION: PASS");
await pool.end();
NODE

echo "[3] WRITE DRIVER OPERATIONS"

cat > src/modules/driver/index.ts <<'TS'
import { Router } from "express";
import { pool } from "../../database/postgres.js";
import {
  getAuthUser,
  requireAuth,
  requireRole
} from "../../middleware/auth.js";

const router = Router();

router.get("/", (_req, res) => {
  res.json({
    service: "driver",
    status: "ok"
  });
});

router.get(
  "/profile",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `SELECT *
         FROM driver_profiles
         WHERE user_id = $1
         LIMIT 1`,
        [user.sub]
      );

      if (!result.rowCount) {
        return res.status(404).json({
          ok: false,
          error: "driver_profile_not_found"
        });
      }

      return res.json({
        ok: true,
        profile: result.rows[0]
      });
    } catch (error) {
      console.error(error);

      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

router.get(
  "/status",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `SELECT
           user_id,
           status,
           availability_status,
           last_online_at,
           last_offline_at
         FROM driver_profiles
         WHERE user_id = $1
         LIMIT 1`,
        [user.sub]
      );

      if (!result.rowCount) {
        return res.status(404).json({
          ok: false,
          error: "driver_profile_not_found"
        });
      }

      return res.json({
        ok: true,
        driver: result.rows[0]
      });
    } catch (error) {
      console.error(error);

      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

router.post(
  "/online",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `UPDATE driver_profiles
         SET
           availability_status = 'online',
           last_online_at = NOW()
         WHERE user_id = $1
           AND status = 'approved'
         RETURNING
           user_id,
           status,
           availability_status,
           last_online_at,
           last_offline_at`,
        [user.sub]
      );

      if (!result.rowCount) {
        const driver = await pool.query(
          `SELECT status
           FROM driver_profiles
           WHERE user_id = $1
           LIMIT 1`,
          [user.sub]
        );

        if (!driver.rowCount) {
          return res.status(404).json({
            ok: false,
            error: "driver_profile_not_found"
          });
        }

        return res.status(403).json({
          ok: false,
          error: "driver_not_approved"
        });
      }

      return res.json({
        ok: true,
        driver: result.rows[0]
      });
    } catch (error) {
      console.error(error);

      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

router.post(
  "/offline",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const activeTrips = await pool.query(
        `SELECT COUNT(*)::int AS count
         FROM trips
         WHERE driver_id = $1
           AND status IN ('accepted', 'arriving', 'started')`,
        [user.sub]
      );

      if ((activeTrips.rows[0]?.count ?? 0) > 0) {
        return res.status(409).json({
          ok: false,
          error: "driver_has_active_trip"
        });
      }

      const result = await pool.query(
        `UPDATE driver_profiles
         SET
           availability_status = 'offline',
           last_offline_at = NOW()
         WHERE user_id = $1
         RETURNING
           user_id,
           status,
           availability_status,
           last_online_at,
           last_offline_at`,
        [user.sub]
      );

      if (!result.rowCount) {
        return res.status(404).json({
          ok: false,
          error: "driver_profile_not_found"
        });
      }

      return res.json({
        ok: true,
        driver: result.rows[0]
      });
    } catch (error) {
      console.error(error);

      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

export default router;
TS

echo "DRIVER OPERATIONS: PASS"

echo "[4] PATCH TRIP ACCEPT ONLINE REQUIREMENT"

node --input-type=module <<'NODE'
import fs from "fs";

const file = "src/modules/trips/index.ts";
let s = fs.readFileSync(file, "utf8");

const oldBlock = `const driver = await pool.query(
        \`SELECT status FROM driver_profiles WHERE user_id = $1\`,
        [user.sub]
      );

      if (driver.rowCount === 0 || driver.rows[0].status !== "approved") {
        return res.status(403).json({
          ok: false,
          error: "driver_not_approved"
        });
      }`;

const newBlock = `const driver = await pool.query(
        \`SELECT status, availability_status
         FROM driver_profiles
         WHERE user_id = $1
         LIMIT 1\`,
        [user.sub]
      );

      if (driver.rowCount === 0) {
        return res.status(404).json({
          ok: false,
          error: "driver_profile_not_found"
        });
      }

      if (driver.rows[0].status !== "approved") {
        return res.status(403).json({
          ok: false,
          error: "driver_not_approved"
        });
      }

      if (driver.rows[0].availability_status !== "online") {
        return res.status(409).json({
          ok: false,
          error: "driver_offline"
        });
      }`;

if (!s.includes(oldBlock)) {
  throw new Error("TRIP ACCEPT BLOCK NOT FOUND");
}

s = s.replace(oldBlock, newBlock);
fs.writeFileSync(file, s);
console.log("TRIP ACCEPT ONLINE GUARD: PASS");
NODE

echo "[5] TYPESCRIPT BUILD"
npx tsc --noEmit
npm run build
echo "BUILD: PASS"

echo "[6] DATABASE FINAL CHECK"

node --input-type=module <<'NODE'
import "dotenv/config";
import { pool } from "./dist/database/postgres.js";

const r = await pool.query(`
  SELECT
    COUNT(*)::int AS total,
    COUNT(*) FILTER (
      WHERE availability_status = 'offline'
    )::int AS offline
  FROM driver_profiles
`);

if (!r.rowCount) {
  throw new Error("DRIVER PROFILE CHECK FAILED");
}

console.log("DRIVER OPERATIONS DB: PASS");
console.log("DRIVER COUNT:", r.rows[0].total);
console.log("OFFLINE COUNT:", r.rows[0].offline);

await pool.end();
NODE

echo "[7] RESTART API"

pkill -f "node dist/server.js" 2>/dev/null || true
sleep 1
nohup node dist/server.js >/tmp/dadia-stage9.log 2>&1 &
sleep 2

curl -fsS http://127.0.0.1:3000/health >/tmp/dadia-stage9-health.json
cat /tmp/dadia-stage9-health.json

echo
echo "HEALTH: PASS"

echo "[8] FULL FUNCTIONAL TEST 1 -> 9"

node --input-type=module <<'NODE'
import http from "http";
import "dotenv/config";

const base = "http://127.0.0.1:3000";

const passengerPhone = "09479795217";
const passengerPassword = "DadiaTest@123";

const driverPhone = "09000000855";
const driverPassword = "DadiaStage7@Test123";

const adminPhone = "09000000789";
const adminPassword = "DadiaStage7@Test123";

function call(path, options = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, base);

    const req = http.request(
      {
        hostname: url.hostname,
        port: Number(url.port),
        path: url.pathname + url.search,
        method: options.method ?? "GET",
        headers: {
          ...(options.headers ?? {})
        }
      },
      res => {
        let body = "";

        res.on("data", chunk => {
          body += chunk;
        });

        res.on("end", () => {
          let parsed;

          try {
            parsed = JSON.parse(body);
          } catch {
            parsed = body;
          }

          resolve({
            response: res,
            body: parsed
          });
        });
      }
    );

    req.on("error", reject);

    if (options.body) {
      req.write(options.body);
    }

    req.end();
  });
}

function pass(name) {
  console.log(`${name}: PASS`);
}

function fail(name, body) {
  console.log(`${name}: FAIL`);
  console.log(typeof body === "string" ? body : JSON.stringify(body));
  process.exitCode = 1;
}

let passengerToken;
let driverToken;
let adminToken;
let tripId;

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
    fail("PASSENGER LOGIN", body);
  }
} catch (e) {
  fail("PASSENGER LOGIN", e.message);
}

try {
  const { response, body } = await call("/passenger/profile", {
    headers: {
      Authorization: `Bearer ${passengerToken}`
    }
  });

  if (response.status === 200 && body.ok && body.profile) {
    pass("PASSENGER PROFILE");
  } else {
    fail("PASSENGER PROFILE", body);
  }
} catch (e) {
  fail("PASSENGER PROFILE", e.message);
}

try {
  const { response } = await call("/driver/status", {
    headers: {
      Authorization: `Bearer ${passengerToken}`
    }
  });

  if (response.status === 403) {
    pass("PASSENGER ROLE PROTECTION");
  } else {
    fail("PASSENGER ROLE PROTECTION", response.status);
  }
} catch (e) {
  fail("PASSENGER ROLE PROTECTION", e.message);
}

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
    fail("DRIVER LOGIN", body);
  }
} catch (e) {
  fail("DRIVER LOGIN", e.message);
}

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
    fail("DRIVER APPROVED PROFILE", body);
  }
} catch (e) {
  fail("DRIVER APPROVED PROFILE", e.message);
}

try {
  const { response, body } = await call("/driver/status", {
    headers: {
      Authorization: `Bearer ${driverToken}`
    }
  });

  if (
    response.status === 200 &&
    body.ok &&
    body.driver?.availability_status === "offline"
  ) {
    pass("DRIVER INITIAL OFFLINE");
  } else {
    fail("DRIVER INITIAL OFFLINE", body);
  }
} catch (e) {
  fail("DRIVER INITIAL OFFLINE", e.message);
}

try {
  const { response, body } = await call("/driver/online", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${driverToken}`,
      "Content-Type": "application/json"
    },
    body: "{}"
  });

  if (
    response.status === 200 &&
    body.ok &&
    body.driver?.availability_status === "online"
  ) {
    pass("DRIVER ONLINE");
  } else {
    fail("DRIVER ONLINE", body);
  }
} catch (e) {
  fail("DRIVER ONLINE", e.message);
}

try {
  const { response, body } = await call("/driver/status", {
    headers: {
      Authorization: `Bearer ${driverToken}`
    }
  });

  if (
    response.status === 200 &&
    body.ok &&
    body.driver?.availability_status === "online" &&
    body.driver?.last_online_at
  ) {
    pass("DRIVER ONLINE STATUS");
  } else {
    fail("DRIVER ONLINE STATUS", body);
  }
} catch (e) {
  fail("DRIVER ONLINE STATUS", e.message);
}

try {
  const { response, body } = await call("/trips", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${passengerToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      origin_address: "Stage 9 Origin",
      destination_address: "Stage 9 Destination",
      origin_lat: 35.6892,
      origin_lng: 51.3890,
      destination_lat: 35.7219,
      destination_lng: 51.3347,
      service_type: "ride",
      vehicle_type: "sedan",
      passenger_note: "STAGE9_FUNCTIONAL_TEST"
    })
  });

  tripId = body.trip?.id ?? null;

  if (
    response.status === 201 &&
    body.ok &&
    tripId &&
    body.trip?.status === "requested"
  ) {
    pass("STAGE 9 TEST TRIP CREATE");
  } else {
    fail("STAGE 9 TEST TRIP CREATE", body);
  }
} catch (e) {
  fail("STAGE 9 TEST TRIP CREATE", e.message);
}

try {
  const { response, body } = await call(`/trips/${tripId}/accept`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${driverToken}`,
      "Content-Type": "application/json"
    },
    body: "{}"
  });

  if (
    response.status === 200 &&
    body.ok &&
    body.trip?.status === "accepted"
  ) {
    pass("DRIVER ONLINE ACCEPT");
  } else {
    fail("DRIVER ONLINE ACCEPT", body);
  }
} catch (e) {
  fail("DRIVER ONLINE ACCEPT", e.message);
}

try {
  const { response, body } = await call(`/driver/offline`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${driverToken}`,
      "Content-Type": "application/json"
    },
    body: "{}"
  });

  if (
    response.status === 409 &&
    body.error === "driver_has_active_trip"
  ) {
    pass("ACTIVE TRIP OFFLINE PROTECTION");
  } else {
    fail("ACTIVE TRIP OFFLINE PROTECTION", body);
  }
} catch (e) {
  fail("ACTIVE TRIP OFFLINE PROTECTION", e.message);
}

try {
  const { response, body } = await call(`/trips/${tripId}/arrive`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${driverToken}`,
      "Content-Type": "application/json"
    },
    body: "{}"
  });

  if (
    response.status === 200 &&
    body.ok &&
    body.trip?.status === "arriving"
  ) {
    pass("ARRIVE");
  } else {
    fail("ARRIVE", body);
  }
} catch (e) {
  fail("ARRIVE", e.message);
}

try {
  const { response, body } = await call(`/trips/${tripId}/start`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${driverToken}`,
      "Content-Type": "application/json"
    },
    body: "{}"
  });

  if (
    response.status === 200 &&
    body.ok &&
    body.trip?.status === "started"
  ) {
    pass("START");
  } else {
    fail("START", body);
  }
} catch (e) {
  fail("START", e.message);
}

try {
  const { response, body } = await call(`/trips/${tripId}/complete`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${driverToken}`,
      "Content-Type": "application/json"
    },
    body: "{}"
  });

  if (
    response.status === 200 &&
    body.ok &&
    body.trip?.status === "completed"
  ) {
    pass("COMPLETE");
  } else {
    fail("COMPLETE", body);
  }
} catch (e) {
  fail("COMPLETE", e.message);
}

try {
  const { response, body } = await call("/driver/offline", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${driverToken}`,
      "Content-Type": "application/json"
    },
    body: "{}"
  });

  if (
    response.status === 200 &&
    body.ok &&
    body.driver?.availability_status === "offline"
  ) {
    pass("DRIVER OFFLINE");
  } else {
    fail("DRIVER OFFLINE", body);
  }
} catch (e) {
  fail("DRIVER OFFLINE", e.message);
}

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
    fail("ADMIN LOGIN", body);
  }
} catch (e) {
  fail("ADMIN LOGIN", e.message);
}

try {
  const { response, body } = await call("/admin/overview", {
    headers: {
      Authorization: `Bearer ${adminToken}`
    }
  });

  if (
    response.status === 200 &&
    body.ok
  ) {
    pass("ADMIN OVERVIEW");
  } else {
    fail("ADMIN OVERVIEW", body);
  }
} catch (e) {
  fail("ADMIN OVERVIEW", e.message);
}

try {
  const { response } = await call("/driver/status", {
    headers: {
      Authorization: "Bearer INVALID_TEST_TOKEN"
    }
  });

  if (response.status === 401) {
    pass("INVALID TOKEN REJECTION");
  } else {
    fail("INVALID TOKEN REJECTION", response.status);
  }
} catch (e) {
  fail("INVALID TOKEN REJECTION", e.message);
}

if (process.exitCode) {
  console.log("==========================================");
  console.log("DADIA STAGE 9: FAIL");
  console.log("DADIA FULL FUNCTIONAL TEST 1 -> 9: FAIL");
  console.log("==========================================");
  process.exit(1);
}

console.log("==========================================");
console.log("DADIA STAGE 9: PASS");
console.log("DADIA FULL FUNCTIONAL TEST 1 -> 9: PASS");
console.log("==========================================");
NODE

echo "=================================================="
echo "DADIA STAGE 9 FINISHED"
echo "=================================================="
