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

function normalizePhone(value: unknown): string {
  const phone = String(value ?? "").trim().replace(/\s+/g, "");
  if (!/^(\+98|0098|98|0)?9\d{9}$/.test(phone)) throw new Error("شماره موبایل نامعتبر است");
  if (phone.startsWith("+98")) return "0" + phone.slice(3);
  if (phone.startsWith("0098")) return "0" + phone.slice(4);
  if (phone.startsWith("98")) return "0" + phone.slice(2);
  if (phone.startsWith("9")) return "0" + phone;
  return phone;
}

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

router.post("/register", async (req, res) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const password = validatePassword(req.body?.password);
    const requestedRole = String(req.body?.role ?? "passenger").toLowerCase();
    const role = requestedRole === "driver" ? "driver" : "passenger";

    const existing = await pool.query(
      `SELECT id FROM users WHERE phone = $1 LIMIT 1`,
      [phone]
    );
    if (existing.rowCount) {
      return res.status(409).json({ ok: false, error: "این شماره قبلا ثبت شده است" });
    }

    const passwordHash = await hashPassword(password);
    const result = await pool.query(
      `INSERT INTO users (phone, role, status, password_hash)
       VALUES ($1, $2::user_role, 'active'::user_status, $3)
       RETURNING id, phone, role, status, created_at`,
      [phone, role, passwordHash]
    );

    const user = result.rows[0];

    if (user.role === "passenger") {
      await pool.query(
        `INSERT INTO passenger_profiles (user_id)
         VALUES ($1)
         ON CONFLICT (user_id) DO NOTHING`,
        [user.id]
      );
    } else if (user.role === "driver") {
      await pool.query(
        `INSERT INTO driver_profiles (user_id)
         VALUES ($1)
         ON CONFLICT (user_id) DO NOTHING`,
        [user.id]
      );
    }

    const tokens = await issueTokens(user);

    return res.status(201).json({ ok: true, user: publicUser(user), ...tokens });
  } catch (error: any) {
    const message = error?.message === "JWT_SECRET is missing or too short"
      ? "تنظیم JWT_SECRET در .env لازم است"
      : (error?.message ?? "خطا در ثبت نام");
    return res.status(400).json({ ok: false, error: message });
  }
});

router.post("/login", async (req, res) => {
  try {
    const phone = normalizePhone(req.body?.phone);
    const password = validatePassword(req.body?.password);

    const result = await pool.query(
      `SELECT id, phone, role, status, created_at, password_hash,
              failed_login_count, locked_until
       FROM users WHERE phone = $1 LIMIT 1`,
      [phone]
    );
    if (!result.rowCount) {
      return res.status(401).json({ ok: false, error: "شماره یا رمز عبور اشتباه است" });
    }

    const user = result.rows[0];
    if (user.locked_until && new Date(user.locked_until).getTime() > Date.now()) {
      return res.status(423).json({ ok: false, error: "حساب موقتا قفل است" });
    }
    if (user.status !== "active") {
      return res.status(403).json({ ok: false, error: "حساب فعال نیست" });
    }

    const valid = user.password_hash
      ? await verifyPassword(password, user.password_hash)
      : false;

    if (!valid) {
      await pool.query(
        `UPDATE users
         SET failed_login_count = failed_login_count + 1,
             locked_until = CASE
               WHEN failed_login_count + 1 >= 5 THEN NOW() + INTERVAL '15 minutes'
               ELSE locked_until
             END
         WHERE id = $1`,
        [user.id]
      );
      return res.status(401).json({ ok: false, error: "شماره یا رمز عبور اشتباه است" });
    }

    const tokens = await issueTokens(user);
    return res.json({ ok: true, user: publicUser(user), ...tokens });
  } catch (error: any) {
    return res.status(400).json({ ok: false, error: error?.message ?? "خطا در ورود" });
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
