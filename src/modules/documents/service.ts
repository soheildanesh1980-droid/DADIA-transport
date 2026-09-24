import { pool } from "../../database/postgres.js";
import type {
  CreateDriverDocumentInput,
  CreateVehicleDocumentInput
} from "./types.js";

function validateDates(
  issuedAt?: string | null,
  expiresAt?: string | null
) {
  if (issuedAt && expiresAt && expiresAt < issuedAt) {
    throw new Error("invalid_document_dates");
  }
}

export async function createDriverDocument(
  input: CreateDriverDocumentInput
) {
  if (!input.documentType?.trim()) {
    throw new Error("document_type_required");
  }

  validateDates(input.issuedAt, input.expiresAt);

  const result = await pool.query(
    `INSERT INTO driver_documents
      (driver_id, document_type, document_number,
       country_code, issued_at, expires_at, metadata)
     VALUES ($1,$2,$3,$4,$5,$6,$7)
     RETURNING *`,
    [
      input.driverId,
      input.documentType.trim(),
      input.documentNumber ?? null,
      input.countryCode ?? null,
      input.issuedAt ?? null,
      input.expiresAt ?? null,
      JSON.stringify(input.metadata ?? {})
    ]
  );

  return result.rows[0];
}

export async function getDriverDocuments(driverId: string) {
  const result = await pool.query(
    `SELECT *
       FROM driver_documents
      WHERE driver_id = $1
      ORDER BY created_at DESC`,
    [driverId]
  );

  return result.rows;
}

export async function createVehicleDocument(
  input: CreateVehicleDocumentInput
) {
  if (!input.documentType?.trim()) {
    throw new Error("document_type_required");
  }

  validateDates(input.issuedAt, input.expiresAt);

  const result = await pool.query(
    `INSERT INTO vehicle_documents
      (vehicle_id, document_type, document_number,
       country_code, issued_at, expires_at, metadata)
     VALUES ($1,$2,$3,$4,$5,$6,$7)
     RETURNING *`,
    [
      input.vehicleId,
      input.documentType.trim(),
      input.documentNumber ?? null,
      input.countryCode ?? null,
      input.issuedAt ?? null,
      input.expiresAt ?? null,
      JSON.stringify(input.metadata ?? {})
    ]
  );

  return result.rows[0];
}

export async function getVehicleDocuments(
  vehicleId: string
) {
  const result = await pool.query(
    `SELECT *
       FROM vehicle_documents
      WHERE vehicle_id = $1
      ORDER BY created_at DESC`,
    [vehicleId]
  );

  return result.rows;
}
