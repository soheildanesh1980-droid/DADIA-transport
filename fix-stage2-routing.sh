#!/data/data/com.termux/files/usr/bin/bash
set -u

cd "$HOME/DADIA-Transport" || exit 1

BACKUP="$HOME/DADIA-Transport-BACKUPS/stage2_route_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"

echo "================================"
echo "DADIA STAGE 2 ROUTING REPAIR"
echo "================================"

echo "[1] BACKUP"
tar --exclude=node_modules --exclude=dist --exclude='*.log' \
  -czf "$BACKUP/project.tar.gz" .

echo "[2] REWRITE APP"

cat > src/app.ts <<'TS'
import express from "express";
import healthRouter from "./routes/health.js";
import passengerRouter from "./modules/passenger/index.js";
import driverRouter from "./modules/driver/index.js";
import adminRouter from "./modules/admin/index.js";

export const app = express();

app.use(express.json());

app.use(healthRouter);

app.use("/passenger", passengerRouter);
app.use("/driver", driverRouter);
app.use("/admin", adminRouter);

export default app;
TS

echo "[3] REWRITE HEALTH"

cat > src/routes/health.ts <<'TS'
import { Router } from "express";
import { checkPostgres } from "../database/postgres.js";
import { checkRedis } from "../cache/redis.js";

const router = Router();

router.get("/health", async (_req, res) => {
  const database = await checkPostgres();
  const redis = await checkRedis();

  const healthy = database && redis;

  res.status(healthy ? 200 : 503).json({
    status: healthy ? "ok" : "degraded",
    service: "DADIA Transport API",
    stage: 2,
    backend: true,
    database,
    redis,
    timestamp: new Date().toISOString()
  });
});

export default router;
TS

echo "[4] REWRITE POSTGRES"

cat > src/database/postgres.ts <<'TS'
import pg from "pg";

const { Client } = pg;

export async function checkPostgres(): Promise<boolean> {
  const client = new Client({
    connectionString:
      process.env.DATABASE_URL ??
      "postgresql://dadia_app@127.0.0.1:5432/dadia_transport",
    connectionTimeoutMillis: 5000
  });

  try {
    await client.connect();
    const result = await client.query("SELECT 1 AS ok");
    await client.end();
    return result.rows[0]?.ok === 1;
  } catch (error) {
    console.error("POSTGRES HEALTH ERROR:", error);
    try {
      await client.end();
    } catch {}
    return false;
  }
}
TS

echo "[5] BUILD"

npm run typecheck || exit 1
npm run build || exit 1

echo "[6] VERIFY COMPILED ROUTE"

if ! grep -q 'health' dist/app.js; then
  echo "ERROR: /health ROUTE NOT PRESENT IN dist/app.js"
  exit 1
fi

echo "COMPILED HEALTH ROUTE: FOUND"

echo "[7] ISOLATED TEST ON 3101"

cat > .stage2-test.mjs <<'JS'
import app from "./dist/app.js";

const server = app.listen(3101, "127.0.0.1", async () => {
  try {
    const r = await fetch("http://127.0.0.1:3101/health");
    const body = await r.text();

    console.log("HTTP_STATUS:", r.status);
    console.log("HEALTH:", body);

    server.close(() => {
      const pass =
        body.includes('"status":"ok"') &&
        body.includes('"database":true') &&
        body.includes('"redis":true");

      process.exit(pass ? 0 : 1);
    });
  } catch (e) {
    console.error(e);
    server.close(() => process.exit(2));
  }
});
JS

node --env-file=.env .stage2-test.mjs
RESULT=$?

rm -f .stage2-test.mjs

echo "BACKUP: $BACKUP"

if [ "$RESULT" -eq 0 ]; then
  echo
  echo "================================"
  echo "DADIA STAGE 2: PASS"
  echo "================================"
  echo "PostgreSQL: OK"
  echo "Redis: OK"
  echo "Health route: OK"
  echo "Backend integration: OK"
  echo
  echo "شماره ۲ کامل شد و به پروژه وصل شد."
else
  echo
  echo "================================"
  echo "DADIA STAGE 2: FAILED"
  echo "================================"
  echo "BACKUP: $BACKUP"
  exit 1
fi
