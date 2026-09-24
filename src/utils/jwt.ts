import {
  createHmac,
  randomBytes,
  timingSafeEqual,
} from "node:crypto";

type JwtPayload = {
  sub: string;
  role: string;
  type: "access" | "refresh";
  iat: number;
  exp: number;
  jti?: string;
};

function base64url(input: string | Buffer): string {
  return Buffer.from(input).toString("base64url");
}

function sign(input: string, secret: string): string {
  return createHmac("sha256", secret).update(input).digest("base64url");
}

export function createToken(
  payload: Omit<JwtPayload, "iat" | "exp">,
  secret: string,
  ttlSeconds: number
): string {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = base64url(JSON.stringify({ ...payload, iat: now, exp: now + ttlSeconds }));
  const unsigned = `${header}.${body}`;
  return `${unsigned}.${sign(unsigned, secret)}`;
}

export function createRefreshToken(
  payload: Omit<JwtPayload, "iat" | "exp" | "jti">,
  secret: string,
  ttlSeconds: number
): string {
  return createToken(
    { ...payload, jti: randomBytes(16).toString("hex") },
    secret,
    ttlSeconds
  );
}

export function verifyToken<T extends JwtPayload>(token: string, secret: string): T {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("invalid_token");

  const unsigned = `${parts[0]}.${parts[1]}`;
  const actual = Buffer.from(parts[2], "base64url");
  const expected = Buffer.from(sign(unsigned, secret), "base64url");

  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
    throw new Error("invalid_signature");
  }

  const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as T;
  if (!payload.exp || payload.exp <= Math.floor(Date.now() / 1000)) {
    throw new Error("token_expired");
  }
  return payload;
}

export function hashToken(token: string): string {
  return createHmac("sha256", process.env.JWT_SECRET ?? "change-me").update(token).digest("hex");
}
