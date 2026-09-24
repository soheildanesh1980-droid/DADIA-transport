#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=========================================="
echo "DADIA STAGE 7 INSTALL"
echo "=========================================="

mkdir -p src/modules/passenger src/modules/driver src/modules/admin

cat > src/modules/passenger/index.ts <<'EOT'
import { Router } from "express";
import { pool } from "../../database/postgres.js";
import { getAuthUser, requireAuth, requireRole } from "../../middleware/auth.js";

const router = Router();

router.get("/", (_req, res) => {
  res.json({
    service: "passenger",
    status: "ok"
  });
});

router.get(
  "/profile",
  requireAuth,
  requireRole("passenger"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `SELECT *
         FROM passenger_profiles
         WHERE user_id = $1
         LIMIT 1`,
        [user.sub]
      );

      if (!result.rowCount) {
        return res.status(404).json({
          ok: false,
          error: "passenger_profile_not_found"
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

export default router;
EOT

cat > src/modules/driver/index.ts <<'EOT'
import { Router } from "express";
import { pool } from "../../database/postgres.js";
import { getAuthUser, requireAuth, requireRole } from "../../middleware/auth.js";

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

export default router;
EOT

cat > src/modules/admin/index.ts <<'EOT'
import { Router } from "express";
import { pool } from "../../database/postgres.js";
import { getAuthUser, requireAuth, requireRole } from "../../middleware/auth.js";

const router = Router();

router.get("/", (_req, res) => {
  res.json({
    service: "admin",
    status: "ok"
  });
});

router.get(
  "/overview",
  requireAuth,
  requireRole("admin"),
  async (_req, res) => {
    try {
      const users = await pool.query(
        `SELECT role, status, COUNT(*)::int AS count
         FROM users
         GROUP BY role, status
         ORDER BY role, status`
      );

      const trips = await pool.query(
        `SELECT status, COUNT(*)::int AS count
         FROM trips
         GROUP BY status
         ORDER BY status`
      );

      const drivers = await pool.query(
        `SELECT status, COUNT(*)::int AS count
         FROM driver_profiles
         GROUP BY status
         ORDER BY status`
      );

      return res.json({
        ok: true,
        users: users.rows,
        trips: trips.rows,
        drivers: drivers.rows
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
  "/drivers/:userId/approve",
  requireAuth,
  requireRole("admin"),
  async (req, res) => {
    try {
      const result = await pool.query(
        `UPDATE driver_profiles
         SET status = 'approved'
         WHERE user_id = $1
         RETURNING *`,
        [req.params.userId]
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

export default router;
EOT

echo "[1] TYPESCRIPT CHECK"
npx tsc --noEmit
echo "TYPESCRIPT: PASS"

echo "[2] DATABASE CHECK"
node --input-type=module <<'EOT'
import "dotenv/config";
import { pool } from "./dist/database/postgres.js";
await pool.query("SELECT 1");
await pool.end();
console.log("DATABASE: PASS");
EOT

echo "[3] STAGE 7 FILE CHECK"
test -f src/modules/passenger/index.ts
test -f src/modules/driver/index.ts
test -f src/modules/admin/index.ts
grep -q '"/profile"' src/modules/passenger/index.ts
grep -q '"/profile"' src/modules/driver/index.ts
grep -q '"/overview"' src/modules/admin/index.ts
grep -q '"/drivers/:userId/approve"' src/modules/admin/index.ts
echo "FILES: PASS"

echo "=========================================="
echo "DADIA STAGE 7 INSTALL: PASS"
echo "=========================================="
