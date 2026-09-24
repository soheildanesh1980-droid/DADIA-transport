import { pool } from "../../database/postgres.js";
import type { CreateMovingOrderInput } from "./types.js";

export async function createMovingOrder(input: CreateMovingOrderInput) {
  if (!input.originAddress || !input.destinationAddress) {
    throw new Error("invalid_address");
  }

  const coordinates = [
    input.originLat,
    input.originLng,
    input.destinationLat,
    input.destinationLng
  ];

  if (coordinates.some((value) => !Number.isFinite(value))) {
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
    input.estimatedWeightKg !== undefined &&
    input.estimatedWeightKg !== null &&
    (!Number.isFinite(input.estimatedWeightKg) ||
      input.estimatedWeightKg <= 0)
  ) {
    throw new Error("invalid_weight");
  }

  if (
    input.estimatedVolumeM3 !== undefined &&
    input.estimatedVolumeM3 !== null &&
    (!Number.isFinite(input.estimatedVolumeM3) ||
      input.estimatedVolumeM3 <= 0)
  ) {
    throw new Error("invalid_volume");
  }

  if (
    input.helperCount !== undefined &&
    input.helperCount !== null &&
    (!Number.isInteger(input.helperCount) ||
      input.helperCount < 0)
  ) {
    throw new Error("invalid_helper_count");
  }

  const result = await pool.query(
    `INSERT INTO moving_orders (
      passenger_id,
      origin_address,
      destination_address,
      origin_lat,
      origin_lng,
      destination_lat,
      destination_lng,
      move_type,
      description,
      estimated_weight_kg,
      estimated_volume_m3,
      vehicle_type,
      helper_count,
      moving_date,
      moving_time,
      recipient_name,
      recipient_phone,
      passenger_phone,
      country_code,
      currency,
      status
    )
    VALUES (
      $1,$2,$3,$4,$5,$6,$7,
      $8,$9,$10,$11,$12,$13,$14,$15,
      $16,$17,$18,
      COALESCE($19,'IR'),
      COALESCE($20,'IRR'),
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
      input.moveType ?? null,
      input.description ?? null,
      input.estimatedWeightKg ?? null,
      input.estimatedVolumeM3 ?? null,
      input.vehicleType ?? null,
      input.helperCount ?? null,
      input.movingDate ?? null,
      input.movingTime ?? null,
      input.recipientName ?? null,
      input.recipientPhone ?? null,
      input.passengerPhone ?? null,
      input.countryCode ?? null,
      input.currency ?? null
    ]
  );

  return result.rows[0];
}

export async function getPassengerMovingOrders(passengerId: string) {
  const result = await pool.query(
    `SELECT *
       FROM moving_orders
      WHERE passenger_id = $1
      ORDER BY created_at DESC`,
    [passengerId]
  );

  return result.rows;
}
