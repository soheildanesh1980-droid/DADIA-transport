import { Router } from "express";
import { pool } from "../../database/postgres.js";
import { hashPassword, verifyPassword } from "../../utils/password.js";
import { createRefreshToken, createToken, hashToken, verifyToken } from "../../utils/jwt.js";

const router = Router();
const ACCESS_TTL = Number(process.env.ACCESS_TOKEN_TTL_SECONDS ?? 900);
const REFRESH_TTL = Number(process.env.REFRESH_TOKEN_TTL_SECONDS ?? 2592000);

function jwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) throw new Error("JWT_SECRET is missing or too short");
  return secret;
}

import { normalizePhone } from "./phone.js";
import { createOtp, verifyOtp } from "./otp.js";
import { getSmsProvider } from "./providers/index.js";

function validatePassword(password: unknown): string {
  const value = String(password ?? "");
  if (value.length < 8) throw new Error("رمز عبور باید حداقل ۸ کاراکتر باشد");
  return value;
}

function publicUser(row: any) {
  return {
    id: row.id,
    phone: row.phone,
    role: row.role,
    status: row.status,
    created_at: row.created_at,
  };
}

async function issueTokens(user: any) {
  const secret = jwtSecret();
  const accessToken = createToken(
    { sub: String(user.id), role: String(user.role), type: "access" },
    secret,
    ACCESS_TTL
  );
  const refreshToken = createRefreshToken(
    { sub: String(user.id), role: String(user.role), type: "refresh" },
    secret,
    REFRESH_TTL
  );

  await pool.query(
    `UPDATE users
     SET refresh_token_hash = $1,
         refresh_token_expires_at = NOW() + ($2 * INTERVAL '1 second'),
         last_login_at = NOW(),
         failed_login_count = 0,
         locked_until = NULL
     WHERE id = $3`,
    [hashToken(refreshToken), REFRESH_TTL, user.id]
  );

  return { accessToken, refreshToken };
}

router.post("/register/request-otp", async (req, res) => {
  try {
    const phone = normalizePhone(req.body?.phone);

    const existing = await pool.query(
      `SELECT id FROM users WHERE phone = $1 LIMIT 1`,
      [phone]
    );

    if ((existing.rowCount ?? 0) > 0) {
      return res.status(409).json({
        ok: false,
        error: "phone_already_registered"
      });
    }

    const smsProvider = getSmsProvider();

    if (!smsProvider) {
      return res.status(503).json({
        ok: false,
        error: "sms_provider_not_configured"
      });
    }

    const otp = await createOtp(phone, "registration");

    const smsResult = await smsProvider.sendOtp({
      phone,
      code: otp.code,
      locale: String(req.body?.locale ?? "fa")
    });

    if (!smsResult.success) {
      return res.status(502).json({
        ok: false,
        error: "sms_send_failed"
      });
    }

    return res.status(200).json({
      ok: true,
      phone,
      expires_at: otp.expires_at,
      message: "otp_sent",
      provider_message_id: smsResult.providerMessageId
    });
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error: error instanceof Error ? error.message : "otp_error"
    });
  }
});

router.post("/register/verify-otp", async (req, res) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const code = String(req.body?.code ?? "").trim();

    await verifyOtp(phone, code, "registration");

    const verificationToken = createToken(
      {
        sub: phone,
        role: "passenger",
        type: "access",
        phone,
        purpose: "passenger_registration"
      } as any,
      jwtSecret(),
      600
    );

    return res.json({
      ok: true,
      phone,
      verified: true,
      verificationToken
    });
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error: error instanceof Error ? error.message : "otp_error"
    });
  }
});

router.post("/register/complete-otp", async (req, res) => {
  try {
    const verificationToken = String(req.body?.verificationToken ?? "").trim();

    if (!verificationToken) {
      return res.status(400).json({
        ok: false,
        error: "registration_verification_token_required"
      });
    }

    const payload = verifyToken<any>(verificationToken, jwtSecret());

    if (
      payload.purpose !== "passenger_registration" ||
      payload.role !== "passenger" ||
      payload.type !== "access" ||
      typeof payload.phone !== "string"
    ) {
      return res.status(401).json({
        ok: false,
        error: "invalid_registration_verification_token"
      });
    }

    const phone = normalizePhone(payload.phone);

    const existing = await pool.query(
      `SELECT id FROM users WHERE phone = $1 LIMIT 1`,
      [phone]
    );

    if (existing.rowCount) {
      return res.status(409).json({
        ok: false,
        error: "phone_already_registered"
      });
    }

    const result = await pool.query(
      `INSERT INTO users
        (phone, role, status, phone_verified_at)
       VALUES
        ($1, 'passenger'::user_role, 'active'::user_status, NOW())
       RETURNING id, phone, role, status, phone_verified_at, created_at`,
      [phone]
    );

    const user = result.rows[0];

    await pool.query(
      `INSERT INTO passenger_profiles (user_id)
       VALUES ($1)
       ON CONFLICT (user_id) DO NOTHING`,
      [user.id]
    );

    const tokens = await issueTokens(user);

    return res.status(201).json({
      ok: true,
      user: publicUser(user),
      ...tokens
    });
  } catch (error: any) {
    const message =
      error?.message === "JWT_SECRET is missing or too short"
        ? "تنظیم JWT_SECRET در .env لازم است"
        : (error?.message ?? "خطا در تکمیل ثبت نام");

    return res.status(400).json({
      ok: false,
      error: message
    });
  }
});

router.post("/register", async (req, res) => {
  try {
    const requestedRole = String(req.body?.role ?? "passenger").toLowerCase();

    if (requestedRole !== "driver") {
      return res.status(410).json({
        ok: false,
        error: "passenger_registration_use_otp"
      });
    }

    const phone = normalizePhone(req.body?.phone);
    const password = validatePassword(req.body?.password);

    const existing = await pool.query(
      `SELECT id FROM users WHERE phone = $1 LIMIT 1`,
      [phone]
    );

    if (existing.rowCount) {
      return res.status(409).json({
        ok: false,
        error: "این شماره قبلا ثبت شده است"
      });
    }

    const passwordHash = await hashPassword(password);

    const result = await pool.query(
      `INSERT INTO users
        (phone, role, status, password_hash, phone_verified_at)
       VALUES
        ($1, 'driver'::user_role, 'active'::user_status, $2, NOW())
       RETURNING id, phone, role, status, phone_verified_at, created_at`,
      [phone, passwordHash]
    );

    const user = result.rows[0];

    await pool.query(
      `INSERT INTO driver_profiles (user_id)
       VALUES ($1)
       ON CONFLICT (user_id) DO NOTHING`,
      [user.id]
    );

    const tokens = await issueTokens(user);

    return res.status(201).json({
      ok: true,
      user: publicUser(user),
      ...tokens
    });
  } catch (error: any) {
    const message =
      error?.message === "JWT_SECRET is missing or too short"
        ? "تنظیم JWT_SECRET در .env لازم است"
        : (error?.message ?? "خطا در ثبت نام");

    return res.status(400).json({
      ok: false,
      error: message
    });
  }
});

router.post("/login/request-otp", async (req, res) => {
  try {
    const phone = normalizePhone(req.body?.phone);

    const existing = await pool.query(
      `SELECT id, status FROM users WHERE phone = $1 LIMIT 1`,
      [phone]
    );

    if (!existing.rowCount) {
      return res.status(404).json({
        ok: false,
        error: "account_not_found"
      });
    }

    if (existing.rows[0].status !== "active") {
      return res.status(403).json({
        ok: false,
        error: "account_not_active"
      });
    }

    const smsProvider = getSmsProvider();

    if (!smsProvider) {
      return res.status(503).json({
        ok: false,
        error: "sms_provider_not_configured"
      });
    }

    const otp = await createOtp(phone, "login");

    const smsResult = await smsProvider.sendOtp({
      phone,
      code: otp.code,
      locale: String(req.body?.locale ?? "fa")
    });

    if (!smsResult.success) {
      return res.status(502).json({
        ok: false,
        error: "sms_send_failed"
      });
    }

    return res.status(200).json({
      ok: true,
      phone,
      expires_at: otp.expires_at,
      message: "otp_sent",
      provider_message_id: smsResult.providerMessageId
    });
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error: error instanceof Error ? error.message : "otp_error"
    });
  }
});

router.post("/login/verify-otp", async (req, res) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const code = String(req.body?.code ?? "").trim();

    await verifyOtp(phone, code, "login");

    const result = await pool.query(
      `SELECT id, phone, role, status, created_at, phone_verified_at
       FROM users
       WHERE phone = $1
       LIMIT 1`,
      [phone]
    );

    if (!result.rowCount) {
      return res.status(404).json({
        ok: false,
        error: "account_not_found"
      });
    }

    const user = result.rows[0];

    if (user.status !== "active") {
      return res.status(403).json({
        ok: false,
        error: "account_not_active"
      });
    }

    const tokens = await issueTokens(user);

    return res.json({
      ok: true,
      user: publicUser(user),
      ...tokens
    });
  } catch (error: any) {
    const message =
      error?.message === "JWT_SECRET is missing or too short"
        ? "تنظیم JWT_SECRET در .env لازم است"
        : (error?.message ?? "خطا در ورود با کد تایید");

    return res.status(400).json({
      ok: false,
      error: message
    });
  }
});

router.post("/login", async (req, res) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const password = validatePassword(req.body?.password);

    const result = await pool.query(
      `SELECT id, phone, role, status, created_at, password_hash,
              failed_login_count, locked_until
       FROM users
       WHERE phone = $1
       LIMIT 1`,
      [phone]
    );

    if (!result.rowCount) {
      return res.status(401).json({
        ok: false,
        error: "شماره یا رمز عبور اشتباه است"
      });
    }

    const user = result.rows[0];

    if (
      user.locked_until &&
      new Date(user.locked_until).getTime() > Date.now()
    ) {
      return res.status(423).json({
        ok: false,
        error: "حساب موقتا قفل است"
      });
    }

    if (user.status !== "active") {
      return res.status(403).json({
        ok: false,
        error: "حساب فعال نیست"
      });
    }

    if (user.role === "passenger") {
      return res.status(410).json({
        ok: false,
        error: "passenger_login_use_otp"
      });
    }

    const valid = user.password_hash
      ? await verifyPassword(password, user.password_hash)
      : false;

    if (!valid) {
      await pool.query(
        `UPDATE users
         SET failed_login_count = failed_login_count + 1,
             locked_until = CASE
               WHEN failed_login_count + 1 >= 5
               THEN NOW() + INTERVAL '15 minutes'
               ELSE locked_until
             END
         WHERE id = $1`,
        [user.id]
      );

      return res.status(401).json({
        ok: false,
        error: "شماره یا رمز عبور اشتباه است"
      });
    }

    const tokens = await issueTokens(user);

    return res.json({
      ok: true,
      user: publicUser(user),
      ...tokens
    });
  } catch (error: any) {
    return res.status(400).json({
      ok: false,
      error: error?.message ?? "خطا در ورود"
    });
  }
});

router.post("/refresh", async (req, res) => {
  try {
    const refreshToken = String(req.body?.refreshToken ?? "");
    if (!refreshToken) return res.status(401).json({ ok: false, error: "refreshToken لازم است" });

    const payload = verifyToken<any>(refreshToken, jwtSecret());
    if (payload.type !== "refresh") throw new Error("invalid_refresh");

    const result = await pool.query(
      `SELECT id, phone, role, status, created_at, refresh_token_hash
       FROM users WHERE id = $1 LIMIT 1`,
      [payload.sub]
    );
    if (!result.rowCount) throw new Error("user_not_found");

    const user = result.rows[0];
    if (user.status !== "active" || !user.refresh_token_hash) throw new Error("refresh_denied");
    if (user.refresh_token_hash !== hashToken(refreshToken)) throw new Error("refresh_denied");

    const tokens = await issueTokens(user);
    return res.json({ ok: true, user: publicUser(user), ...tokens });
  } catch {
    return res.status(401).json({ ok: false, error: "refreshToken نامعتبر یا منقضی شده است" });
  }
});

router.post("/logout", async (req, res) => {
  try {
    const refreshToken = String(req.body?.refreshToken ?? "");
    if (refreshToken) {
      try {
        const payload = verifyToken<any>(refreshToken, jwtSecret());
        await pool.query(
          `UPDATE users SET refresh_token_hash = NULL, refresh_token_expires_at = NULL WHERE id = $1`,
          [payload.sub]
        );
      } catch {}
    }
    return res.json({ ok: true });
  } catch {
    return res.status(200).json({ ok: true });
  }
});

router.get("/me", async (req, res) => {
  const header = req.header("authorization");
  if (!header?.startsWith("Bearer ")) return res.status(401).json({ ok: false, error: "احراز هویت لازم است" });

  try {
    const payload = verifyToken<any>(header.slice(7), jwtSecret());
    if (payload.type !== "access") throw new Error("invalid");
    const result = await pool.query(
      `SELECT id, phone, role, status, created_at FROM users WHERE id = $1 LIMIT 1`,
      [payload.sub]
    );
    if (!result.rowCount) return res.status(404).json({ ok: false, error: "کاربر پیدا نشد" });
    return res.json({ ok: true, user: publicUser(result.rows[0]) });
  } catch {
    return res.status(401).json({ ok: false, error: "توکن نامعتبر یا منقضی شده است" });
  }
});

export default router;
