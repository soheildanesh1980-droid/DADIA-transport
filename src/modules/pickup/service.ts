import { pool } from "../../database/postgres.js";
import type { CreatePickupOrderInput } from "./types.js";

export async function createPickupOrder(input: CreatePickupOrderInput) {
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
    input.weightKg !== undefined &&
    input.weightKg !== null &&
    (!Number.isFinite(input.weightKg) || input.weightKg <= 0)
  ) {
    throw new Error("invalid_weight");
  }

  if (
    input.volumeM3 !== undefined &&
    input.volumeM3 !== null &&
    (!Number.isFinite(input.volumeM3) || input.volumeM3 <= 0)
  ) {
    throw new Error("invalid_volume");
  }

  const result = await pool.query(
    `INSERT INTO pickup_orders (
      passenger_id,
      origin_address,
      destination_address,
      origin_lat,
      origin_lng,
      destination_lat,
      destination_lng,
      cargo_type,
      cargo_description,
      weight_kg,
      volume_m3,
      vehicle_type,
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
      COALESCE($16,'IR'),
      COALESCE($17,'IRR'),
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
      input.cargoType ?? null,
      input.cargoDescription ?? null,
      input.weightKg ?? null,
      input.volumeM3 ?? null,
      input.vehicleType ?? null,
      input.recipientName ?? null,
      input.recipientPhone ?? null,
      input.passengerPhone ?? null,
      input.countryCode ?? null,
      input.currency ?? null
    ]
  );

  return result.rows[0];
}

export async function getPassengerPickupOrders(passengerId: string) {
  const result = await pool.query(
    `SELECT *
       FROM pickup_orders
      WHERE passenger_id = $1
      ORDER BY created_at DESC`,
    [passengerId]
  );

  return result.rows;
}
