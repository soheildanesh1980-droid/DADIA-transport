import { Router } from "express";
import { pool } from "../../database/postgres.js";
import {
  getAuthUser,
  requireAuth,
  requireRole
} from "../../middleware/auth.js";

const router = Router();

/*
 * Passenger Operations - Stage 10
 *
 * Dedicated passenger endpoints:
 * GET  /passenger/
 * GET  /passenger/profile
 * GET  /passenger/trips
 * GET  /passenger/trips/active
 * GET  /passenger/trips/:id
 * POST /passenger/trips/:id/cancel
 */

router.get("/", (_req, res) => {
  return res.json({
    service: "passenger",
    status: "ok",
    stage: 10
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

router.get(
  "/trips",
  requireAuth,
  requireRole("passenger"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `SELECT *
         FROM trips
         WHERE passenger_id = $1
         ORDER BY created_at DESC`,
        [user.sub]
      );

      return res.json({
        ok: true,
        count: result.rowCount,
        trips: result.rows
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
  "/trips/active",
  requireAuth,
  requireRole("passenger"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `SELECT *
         FROM trips
         WHERE passenger_id = $1
           AND status IN ('requested', 'searching', 'accepted', 'arriving', 'started')
         ORDER BY created_at DESC
         LIMIT 1`,
        [user.sub]
      );

      if (!result.rowCount) {
        return res.json({
          ok: true,
          active: false,
          trip: null
        });
      }

      return res.json({
        ok: true,
        active: true,
        trip: result.rows[0]
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
  "/trips/:id",
  requireAuth,
  requireRole("passenger"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `SELECT *
         FROM trips
         WHERE id = $1
           AND passenger_id = $2
         LIMIT 1`,
        [req.params.id, user.sub]
      );

      if (!result.rowCount) {
        return res.status(404).json({
          ok: false,
          error: "trip_not_found"
        });
      }

      return res.json({
        ok: true,
        trip: result.rows[0]
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
  "/trips/:id/cancel",
  requireAuth,
  requireRole("passenger"),
  async (req, res) => {
    const client = await pool.connect();

    try {
      const user = getAuthUser(req);

      await client.query("BEGIN");

      const result = await client.query(
        `SELECT *
         FROM trips
         WHERE id = $1
           AND passenger_id = $2
         FOR UPDATE`,
        [req.params.id, user.sub]
      );

      if (!result.rowCount) {
        await client.query("ROLLBACK");
        return res.status(404).json({
          ok: false,
          error: "trip_not_found"
        });
      }

      const trip = result.rows[0];

      if (
        !["requested", "searching", "accepted", "arriving"].includes(
          trip.status
        )
      ) {
        await client.query("ROLLBACK");
        return res.status(409).json({
          ok: false,
          error: "trip_cannot_be_cancelled",
          status: trip.status
        });
      }

      const updated = await client.query(
        `UPDATE trips
         SET status = 'cancelled',
             updated_at = NOW()
         WHERE id = $1
         RETURNING *`,
        [req.params.id]
      );

      await client.query("COMMIT");

      return res.json({
        ok: true,
        trip: updated.rows[0]
      });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => {});
      console.error(error);

      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    } finally {
      client.release();
    }
  }
);

export default router;
