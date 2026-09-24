import crypto from "node:crypto";
import { pool } from "../../database/postgres.js";
import { redis } from "../../cache/redis.js";

const OTP_TTL_MINUTES = 5;
const MAX_ATTEMPTS = 5;

const OTP_COOLDOWN_SECONDS = 60;
const OTP_MAX_REQUESTS_PER_HOUR = 5;

function hashOtp(code: string): string {
  return crypto
    .createHash("sha256")
    .update(code)
    .digest("hex");
}

function cooldownKey(phone: string, purpose: string): string {
  return `otp:${purpose}:cooldown:${phone}`;
}

function hourlyKey(phone: string, purpose: string): string {
  return `otp:${purpose}:hourly:${phone}`;
}

async function checkRateLimit(
  phone: string,
  purpose: string
): Promise<void> {
  const cooldown = await redis.get(cooldownKey(phone, purpose));

  if (cooldown) {
    throw new Error("otp_rate_limited");
  }

  const hourly = await redis.get(hourlyKey(phone, purpose));
  const count = hourly ? Number(hourly) : 0;

  if (count >= OTP_MAX_REQUESTS_PER_HOUR) {
    throw new Error("otp_hourly_limit_exceeded");
  }
}

async function recordRateLimit(
  phone: string,
  purpose: string
): Promise<void> {
  await redis.set(
    cooldownKey(phone, purpose),
    "1",
    "EX",
    OTP_COOLDOWN_SECONDS
  );

  const key = hourlyKey(phone, purpose);
  const count = await redis.incr(key);

  if (count === 1) {
    await redis.expire(key, 60 * 60);
  }
}

export function generateOtp(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

export async function createOtp(
  phone: string,
  purpose = "registration"
) {
  await checkRateLimit(phone, purpose);

  const code = generateOtp();
  const codeHash = hashOtp(code);

  await pool.query(
    `UPDATE auth_otps
        SET consumed_at = NOW()
      WHERE phone = $1
        AND purpose = $2
        AND consumed_at IS NULL`,
    [phone, purpose]
  );

  const result = await pool.query(
    `INSERT INTO auth_otps
      (phone, purpose, code_hash, expires_at, max_attempts)
     VALUES ($1, $2, $3, NOW() + INTERVAL '${OTP_TTL_MINUTES} minutes', $4)
     RETURNING id, phone, purpose, expires_at, attempts, max_attempts`,
    [phone, purpose, codeHash, MAX_ATTEMPTS]
  );

  await recordRateLimit(phone, purpose);

  return {
    ...result.rows[0],
    code
  };
}

export async function verifyOtp(
  phone: string,
  code: string,
  purpose = "registration"
): Promise<boolean> {
  const result = await pool.query(
    `SELECT *
       FROM auth_otps
      WHERE phone = $1
        AND purpose = $2
        AND consumed_at IS NULL
      ORDER BY created_at DESC
      LIMIT 1`,
    [phone, purpose]
  );

  const row = result.rows[0];

  if (!row) {
    throw new Error("otp_not_found");
  }

  if (new Date(row.expires_at).getTime() <= Date.now()) {
    throw new Error("otp_expired");
  }

  if (row.attempts >= row.max_attempts) {
    throw new Error("otp_attempts_exceeded");
  }

  const valid = hashOtp(code) === row.code_hash;

  if (!valid) {
    await pool.query(
      `UPDATE auth_otps
          SET attempts = attempts + 1
        WHERE id = $1`,
      [row.id]
    );

    throw new Error("otp_invalid");
  }

  await pool.query(
    `UPDATE auth_otps
        SET consumed_at = NOW()
      WHERE id = $1`,
    [row.id]
  );

  return true;
}
