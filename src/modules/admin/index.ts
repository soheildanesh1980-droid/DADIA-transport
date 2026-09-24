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
