import { pool } from "../../database/postgres.js";
import type { CreateEarningInput, SettlementInput } from "./types.js";

export async function createEarning(input: CreateEarningInput) {
  const platformFee = input.platformFee ?? 0;
  const netAmount = input.grossAmount - platformFee;

  if (input.grossAmount < 0 || platformFee < 0 || netAmount < 0) {
    throw new Error("invalid_earning_amount");
  }

  const result = await pool.query(
    `INSERT INTO driver_earnings
      (driver_id, trip_id, gross_amount, platform_fee, net_amount,
       currency, status, description)
     VALUES ($1,$2,$3,$4,$5,$6,'available',$7)
     RETURNING *`,
    [
      input.driverId,
      input.tripId ?? null,
      input.grossAmount,
      platformFee,
      netAmount,
      input.currency ?? "IRR",
      input.description ?? null
    ]
  );

  return result.rows[0];
}

export async function getDriverEarnings(driverId: string) {
  const result = await pool.query(
    `SELECT *
       FROM driver_earnings
      WHERE driver_id = $1
      ORDER BY created_at DESC`,
    [driverId]
  );

  const totals = await pool.query(
    `SELECT
       COALESCE(SUM(gross_amount),0) AS gross_amount,
       COALESCE(SUM(platform_fee),0) AS platform_fee,
       COALESCE(SUM(net_amount),0) AS net_amount
       FROM driver_earnings
      WHERE driver_id = $1
        AND status <> 'settled'`,
    [driverId]
  );

  return {
    earnings: result.rows,
    totals: totals.rows[0]
  };
}

export async function createSettlement(input: SettlementInput) {
  if (input.amount <= 0) {
    throw new Error("invalid_settlement_amount");
  }

  const available = await pool.query(
    `SELECT COALESCE(SUM(net_amount),0) AS available
       FROM driver_earnings
      WHERE driver_id = $1
        AND currency = $2
        AND status = 'available'`,
    [input.driverId, input.currency ?? "IRR"]
  );

  const availableAmount = Number(available.rows[0].available);

  if (input.amount > availableAmount) {
    throw new Error("insufficient_available_balance");
  }

  const settlement = await pool.query(
    `INSERT INTO driver_settlements
      (driver_id, amount, currency, status)
     VALUES ($1,$2,$3,'pending')
     RETURNING *`,
    [input.driverId, input.amount, input.currency ?? "IRR"]
  );

  return settlement.rows[0];
}

export async function getDriverSettlements(driverId: string) {
  const result = await pool.query(
    `SELECT *
       FROM driver_settlements
      WHERE driver_id = $1
      ORDER BY created_at DESC`,
    [driverId]
  );

  return result.rows;
}
