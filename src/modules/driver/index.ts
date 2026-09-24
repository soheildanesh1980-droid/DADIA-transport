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



router.get(
  "/location/current",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `SELECT
           user_id,
           current_latitude,
           current_longitude,
           location_updated_at
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
        location: result.rows[0]
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
  "/location",
  requireAuth,
  requireRole("driver"),
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const latitude = Number(req.body?.latitude);
      const longitude = Number(req.body?.longitude);

      if (
        !Number.isFinite(latitude) ||
        !Number.isFinite(longitude) ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180
      ) {
        return res.status(400).json({
          ok: false,
          error: "invalid_coordinates"
        });
      }

      const result = await pool.query(
        `UPDATE driver_profiles
         SET current_latitude = $1,
             current_longitude = $2,
             location_updated_at = NOW()
         WHERE user_id = $3
         RETURNING
           user_id,
           current_latitude,
           current_longitude,
           location_updated_at`,
        [latitude, longitude, user.sub]
      );

      if (!result.rowCount) {
        return res.status(404).json({
          ok: false,
          error: "driver_profile_not_found"
        });
      }

      return res.json({
        ok: true,
        location: result.rows[0]
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
