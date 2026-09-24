import { dispatchNearestDriver } from "./matching.js";
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

router.post(
  "/:id/dispatch",
  requireAuth,
  requireRole("admin"),
  async (req, res) => {
    try {
      const result = await dispatchNearestDriver(String(req.params.id));
      return res.status(result.status).json(result.body);
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
  "/:id/tracking",
  requireAuth,
  async (req, res) => {
    try {
      const user = getAuthUser(req);

      const result = await pool.query(
        `SELECT
           t.id,
           t.status,
           t.passenger_id,
           t.driver_id,
           d.current_latitude,
           d.current_longitude,
           d.location_updated_at
         FROM trips t
         LEFT JOIN driver_profiles d
           ON d.user_id = t.driver_id
         WHERE t.id = $1
         LIMIT 1`,
        [String(req.params.id)]
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
        tracking: {
          trip_id: trip.id,
          status: trip.status,
          driver_id: trip.driver_id,
          latitude: trip.current_latitude,
          longitude: trip.current_longitude,
          updated_at: trip.location_updated_at
        }
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
        `SELECT status, availability_status
         FROM driver_profiles
         WHERE user_id = $1
         LIMIT 1`,
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
