import { pool } from "../../database/postgres.js";
import type { CreateCourierOrderInput } from "./types.js";

export async function createCourierOrder(input: CreateCourierOrderInput) {
  if (!input.originAddress || !input.destinationAddress) {
    throw new Error("invalid_address");
  }

  if (
    !Number.isFinite(input.originLat) ||
    !Number.isFinite(input.originLng) ||
    !Number.isFinite(input.destinationLat) ||
    !Number.isFinite(input.destinationLng)
  ) {
    throw new Error("invalid_coordinates");
  }

  if (
    input.originLat < -90 || input.originLat > 90 ||
    input.destinationLat < -90 || input.destinationLat > 90 ||
    input.originLng < -180 || input.originLng > 180 ||
    input.destinationLng < -180 || input.destinationLng > 180
  ) {
    throw new Error("invalid_coordinates");
  }

  if (
    input.packageWeightKg !== undefined &&
    input.packageWeightKg !== null &&
    (!Number.isFinite(input.packageWeightKg) || input.packageWeightKg <= 0)
  ) {
    throw new Error("invalid_package_weight");
  }

  const result = await pool.query(
    `INSERT INTO courier_orders (
      passenger_id,
      origin_address,
      destination_address,
      origin_lat,
      origin_lng,
      destination_lat,
      destination_lng,
      package_description,
      package_weight_kg,
      recipient_name,
      recipient_phone,
      passenger_phone,
      country_code,
      currency,
      status
    )
    VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,
      COALESCE($13,'IR'),
      COALESCE($14,'IRR'),
      'requested'
    )
    RETURNING *`,
    [
      input.passengerId,
      input.originAddress,
      input.destinationAddress,
      input.originLat,
      input.originLng,
      input.destinationLat,
      input.destinationLng,
      input.packageDescription ?? null,
      input.packageWeightKg ?? null,
      input.recipientName ?? null,
      input.recipientPhone ?? null,
      input.passengerPhone ?? null,
      input.countryCode ?? null,
      input.currency ?? null
    ]
  );

  return result.rows[0];
}

export async function getPassengerCourierOrders(passengerId: string) {
  const result = await pool.query(
    `SELECT *
       FROM courier_orders
      WHERE passenger_id = $1
      ORDER BY created_at DESC`,
    [passengerId]
  );

  return result.rows;
}
