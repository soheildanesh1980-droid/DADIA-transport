import { pool } from "../../database/postgres.js";
import type { CreateVehicleInput } from "./types.js";

export async function createVehicle(input: CreateVehicleInput) {
  if (!input.vehicleType?.trim()) {
    throw new Error("vehicle_type_required");
  }

  if (
    input.modelYear !== undefined &&
    input.modelYear !== null &&
    (!Number.isInteger(input.modelYear) ||
      input.modelYear < 1900 ||
      input.modelYear > 2200)
  ) {
    throw new Error("invalid_model_year");
  }

  const result = await pool.query(
    `INSERT INTO vehicles
      (driver_id, vehicle_type, make, model, model_year,
       color, plate_number, country_code)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
     RETURNING *`,
    [
      input.driverId,
      input.vehicleType.trim(),
      input.make ?? null,
      input.model ?? null,
      input.modelYear ?? null,
      input.color ?? null,
      input.plateNumber ?? null,
      input.countryCode ?? null
    ]
  );

  return result.rows[0];
}

export async function getDriverVehicles(driverId: string) {
  const result = await pool.query(
    `SELECT *
       FROM vehicles
      WHERE driver_id = $1
      ORDER BY created_at DESC`,
    [driverId]
  );

  return result.rows;
}
