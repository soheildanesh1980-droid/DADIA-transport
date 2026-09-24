import { pool } from "../../database/postgres.js";

export async function dispatchNearestDriver(tripId: string) {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const tripResult = await client.query(
      `SELECT id,
              status,
              origin_latitude,
              origin_longitude
       FROM trips
       WHERE id = $1
       FOR UPDATE`,
      [tripId]
    );

    if (!tripResult.rowCount) {
      await client.query("ROLLBACK");
      return {
        status: 404,
        body: { ok: false, error: "trip_not_found" }
      };
    }

    const trip = tripResult.rows[0];

    if (!["requested", "searching"].includes(trip.status)) {
      await client.query("ROLLBACK");
      return {
        status: 409,
        body: {
          ok: false,
          error: "trip_not_available_for_dispatch",
          trip_status: trip.status
        }
      };
    }

    const drivers = await client.query(
      `SELECT
         user_id,
         current_latitude,
         current_longitude,
         (
           6371 * 2 * ASIN(
             SQRT(
               POWER(
                 SIN(RADIANS(current_latitude - $1) / 2),
                 2
               )
               +
               COS(RADIANS($1))
               * COS(RADIANS(current_latitude))
               * POWER(
                 SIN(RADIANS(current_longitude - $2) / 2),
                 2
               )
             )
           )
         ) AS distance_km
       FROM driver_profiles
       WHERE status = 'approved'
         AND availability_status = 'online'
         AND current_latitude IS NOT NULL
         AND current_longitude IS NOT NULL
       ORDER BY distance_km ASC
       LIMIT 1
       FOR UPDATE`,
      [
        Number(trip.origin_latitude),
        Number(trip.origin_longitude)
      ]
    );

    if (!drivers.rowCount) {
      await client.query("ROLLBACK");
      return {
        status: 409,
        body: {
          ok: false,
          error: "no_available_driver"
        }
      };
    }

    const driver = drivers.rows[0];

    const update = await client.query(
      `UPDATE trips
       SET driver_id = $1,
           status = 'accepted',
           updated_at = NOW()
       WHERE id = $2
         AND status IN ('requested', 'searching')
       RETURNING *`,
      [driver.user_id, tripId]
    );

    if (!update.rowCount) {
      await client.query("ROLLBACK");
      return {
        status: 409,
        body: {
          ok: false,
          error: "trip_dispatch_conflict"
        }
      };
    }

    await client.query("COMMIT");

    return {
      status: 200,
      body: {
        ok: true,
        trip: update.rows[0],
        match: {
          driver_id: driver.user_id,
          distance_km: Number(driver.distance_km)
        }
      }
    };
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});

    console.error(error);

    return {
      status: 500,
      body: {
        ok: false,
        error: "internal_error"
      }
    };
  } finally {
    client.release();
  }
}
