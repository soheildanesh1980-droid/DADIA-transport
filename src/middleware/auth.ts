import type { Request, Response, NextFunction } from "express";
import { verifyToken } from "../utils/jwt.js";

export type AuthUser = { sub: string; role: string; type: "access" | "refresh" };

declare global {
  namespace Express {
    interface Request {
      authUser?: AuthUser;
    }
  }
}

export function getAuthUser(req: Request): AuthUser {
  if (!req.authUser) {
    throw new Error("AUTH_USER_MISSING");
  }
  return req.authUser;
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.header("authorization");
  if (!header?.startsWith("Bearer ")) {
    return res.status(401).json({ ok: false, error: "احراز هویت لازم است" });
  }

  try {
    const token = header.slice(7);
    const payload = verifyToken<AuthUser & { iat: number; exp: number }>(
      token,
      process.env.JWT_SECRET ?? ""
    );
    if (payload.type !== "access") {
      return res.status(401).json({ ok: false, error: "توکن نامعتبر است" });
    }
    req.authUser = { sub: payload.sub, role: payload.role, type: payload.type };
    next();
  } catch {
    return res.status(401).json({ ok: false, error: "توکن نامعتبر یا منقضی شده است" });
  }
}

export function requireRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.authUser || !roles.includes(req.authUser.role)) {
      return res.status(403).json({ ok: false, error: "دسترسی مجاز نیست" });
    }
    next();
  };
}
