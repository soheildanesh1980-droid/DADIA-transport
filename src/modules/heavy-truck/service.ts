import { pool } from "../../database/postgres.js";
import type { CreateHeavyTruckOrderInput } from "./types.js";

function validateCoordinates(
  latitude: number,
  longitude: number
): boolean {
  return (
    Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180
  );
}

export async function createHeavyTruckOrder(
  input: CreateHeavyTruckOrderInput
) {
  if (
    !input.originAddress?.trim() ||
    !input.destinationAddress?.trim()
  ) {
    throw new Error("invalid_address");
  }

  if (
    !validateCoordinates(input.originLat, input.originLng) ||
    !validateCoordinates(
      input.destinationLat,
      input.destinationLng
    )
  ) {
    throw new Error("invalid_coordinates");
  }

  if (
    input.weightTon !== undefined &&
    input.weightTon !== null &&
    (!Number.isFinite(input.weightTon) || input.weightTon <= 0)
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

  if (
    input.axleCount !== undefined &&
    input.axleCount !== null &&
    (!Number.isInteger(input.axleCount) || input.axleCount <= 0)
  ) {
    throw new Error("invalid_axle_count");
  }

  const result = await pool.query(
    `INSERT INTO heavy_truck_orders (
      passenger_id,
      origin_address,
      destination_address,
      origin_lat,
      origin_lng,
      destination_lat,
      destination_lng,
      cargo_type,
      cargo_description,
      weight_ton,
      volume_m3,
      vehicle_type,
      truck_type,
      axle_count,
      requires_trailer,
      trailer_type,
      loading_type,
      special_requirements,
      recipient_name,
      recipient_phone,
      passenger_phone,
      country_code,
      currency,
      status
    )
    VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,
      $15,$16,$17,$18,$19,$20,$21,$22,$23,'requested'
    )
    RETURNING *`,
    [
      input.passengerId,
      input.originAddress.trim(),
      input.destinationAddress.trim(),
      input.originLat,
      input.originLng,
      input.destinationLat,
      input.destinationLng,
      input.cargoType ?? null,
      input.cargoDescription ?? null,
      input.weightTon ?? null,
      input.volumeM3 ?? null,
      input.vehicleType ?? null,
      input.truckType ?? null,
      input.axleCount ?? null,
      input.requiresTrailer ?? false,
      input.trailerType ?? null,
      input.loadingType ?? null,
      input.specialRequirements ?? null,
      input.recipientName ?? null,
      input.recipientPhone ?? null,
      input.passengerPhone ?? null,
      input.countryCode ?? "IR",
      input.currency ?? "IRR"
    ]
  );

  return result.rows[0];
}

export async function getPassengerHeavyTruckOrders(
  passengerId: string
) {
  const result = await pool.query(
    `SELECT *
       FROM heavy_truck_orders
      WHERE passenger_id = $1
      ORDER BY created_at DESC`,
    [passengerId]
  );

  return result.rows;
}
