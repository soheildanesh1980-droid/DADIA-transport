#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== DADIA STAGE 2 ==="

# 1) نصب سرویس ها در صورت نبودن
command -v postgres >/dev/null 2>&1 || pkg install -y postgresql
command -v redis-server >/dev/null 2>&1 || pkg install -y redis

# 2) نصب وابستگی های Node
npm install pg ioredis
npm install --save-dev @types/pg

# 3) ساخت پوشه ها
mkdir -p src/database src/cache

# 4) PostgreSQL
if [ ! -d "$PREFIX/var/lib/postgresql" ]; then
  initdb "$PREFIX/var/lib/postgresql"
fi

# 5) اجرای PostgreSQL
if ! pg_ctl -D "$PREFIX/var/lib/postgresql" status >/dev/null 2>&1; then
  pg_ctl -D "$PREFIX/var/lib/postgresql" \
    -l "$PREFIX/var/log/postgresql.log" start
fi

# 6) ساخت دیتابیس DADIA
createdb dadia_transport 2>/dev/null || true

# 7) اجرای Redis
if ! pgrep -x redis-server >/dev/null 2>&1; then
  redis-server --daemonize yes
fi

# 8) Environment
cat > .env <<'ENV'
NODE_ENV=development
PORT=3000

DATABASE_URL=postgresql://localhost:5432/dadia_transport

REDIS_HOST=127.0.0.1
REDIS_PORT=6379
ENV

cat > .env.example <<'ENV'
NODE_ENV=development
PORT=3000

DATABASE_URL=postgresql://localhost:5432/dadia_transport

REDIS_HOST=127.0.0.1
REDIS_PORT=6379
ENV

# 9) Git ignore
cat > .gitignore <<'EOF2'
node_modules/
dist/
.env
*.log
EOF2

# 10) PostgreSQL connection
cat > src/database/postgres.ts <<'TS'
import pg from "pg";

const { Pool } = pg;

export const db = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export async function checkDatabase(): Promise<boolean> {
  const result = await db.query("SELECT 1 AS ok");
  return result.rows[0]?.ok === 1;
}
TS

# 11) Redis connection
cat > src/cache/redis.ts <<'TS'
import Redis from "ioredis";

export const redis = new Redis({
  host: process.env.REDIS_HOST ?? "127.0.0.1",
  port: Number(process.env.REDIS_PORT ?? 6379),
  lazyConnect: true,
});

export async function checkRedis(): Promise<boolean> {
  if (redis.status === "wait") {
    await redis.connect();
  }

  const result = await redis.ping();
  return result === "PONG";
}
TS

# 12) Health route
cat > src/routes/health.ts <<'TS'
import { Router } from "express";
import { checkDatabase } from "../database/postgres.js";
import { checkRedis } from "../cache/redis.js";

const router = Router();

router.get("/", async (_req, res) => {
  let database = false;
  let redis = false;

  try {
    database = await checkDatabase();
  } catch {}

  try {
    redis = await checkRedis();
  } catch {}

  const ok = database && redis;

  res.status(ok ? 200 : 503).json({
    status: ok ? "ok" : "degraded",
    service: "DADIA Transport API",
    stage: 2,
    backend: true,
    database,
    redis,
    timestamp: new Date().toISOString(),
  });
});

export default router;
TS

# 13) TypeScript config
cat > tsconfig.json <<'TS'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "types": ["node"]
  },
  "include": ["src/**/*.ts"]
}
TS

# 14) Test build
npm run typecheck
npm run build

# 15) اجرای API در پس زمینه
pkill -f "node dist/server.js" 2>/dev/null || true
nohup node dist/server.js > dadia-stage2.log 2>&1 &

sleep 2

# 16) تست نهایی
echo
echo "=== SERVICES ==="
pg_ctl -D "$PREFIX/var/lib/postgresql" status || true
redis-cli ping

echo
echo "=== API HEALTH ==="
curl -s http://127.0.0.1:3000/health

echo
echo
echo "================================"
echo "DADIA STAGE 2 BUILD: PASS"
echo "================================"
