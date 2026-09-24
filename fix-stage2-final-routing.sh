#!/data/data/com.termux/files/usr/bin/bash
set -u

cd "$HOME/DADIA-Transport" || exit 1

BACKUP="$HOME/DADIA-Transport-BACKUPS/stage2_final_route_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"

echo "================================"
echo "DADIA STAGE 2 FINAL ROUTING"
echo "================================"

echo "[1] BACKUP"
tar --exclude=node_modules --exclude=dist --exclude='*.log' \
  -czf "$BACKUP/project.tar.gz" .

echo "[2] PASSENGER MODULE"

cat > src/modules/passenger/index.ts <<'TS'
import { Router } from "express";

const router = Router();

router.get("/", (_req, res) => {
  res.json({
    service: "passenger",
    status: "ok"
  });
});

export default router;
TS

echo "[3] DRIVER MODULE"

cat > src/modules/driver/index.ts <<'TS'
import { Router } from "express";

const router = Router();

router.get("/", (_req, res) => {
  res.json({
    service: "driver",
    status: "ok"
  });
});

export default router;
TS

echo "[4] ADMIN MODULE"

cat > src/modules/admin/index.ts <<'TS'
import { Router } from "express";

const router = Router();

router.get("/", (_req, res) => {
  res.json({
    service: "admin",
    status: "ok"
  });
});

export default router;
TS

echo "[5] APP"

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

echo "[6] HEALTH"

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

echo "[7] POSTGRES"

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

echo "[8] TYPECHECK"

npm run typecheck || {
  echo "TYPECHECK FAILED"
  echo "BACKUP: $BACKUP"
  exit 1
}

echo "[9] BUILD"

npm run build || {
  echo "BUILD FAILED"
  echo "BACKUP: $BACKUP"
  exit 1
}

echo "[10] ISOLATED TEST ON 3101"

cat > .stage2-test.mjs <<'JS'
import app from "./dist/app.js";

const server = app.listen(3101, "127.0.0.1", async () => {
  try {
    const health = await fetch("http://127.0.0.1:3101/health");
    const body = await health.text();

    console.log("HTTP_STATUS:", health.status);
    console.log("HEALTH:", body);

    const passenger = await fetch("http://127.0.0.1:3101/passenger");
    console.log("PASSENGER:", passenger.status);

    const driver = await fetch("http://127.0.0.1:3101/driver");
    console.log("DRIVER:", driver.status);

    const admin = await fetch("http://127.0.0.1:3101/admin");
    console.log("ADMIN:", admin.status);

    const pass =
      health.status === 200 &&
      body.includes('"status":"ok"') &&
      body.includes('"database":true') &&
      body.includes('"redis":true') &&
      passenger.status === 200 &&
      driver.status === 200 &&
      admin.status === 200;

    server.close(() => process.exit(pass ? 0 : 1));
  } catch (error) {
    console.error("TEST ERROR:", error);
    server.close(() => process.exit(2));
  }
});
JS

node --env-file=.env .stage2-test.mjs
RESULT=$?

rm -f .stage2-test.mjs

echo
echo "BACKUP: $BACKUP"
echo "================================"

if [ "$RESULT" -eq 0 ]; then
  echo "DADIA STAGE 2: PASS"
  echo "PostgreSQL: OK"
  echo "Redis: OK"
  echo "Health: OK"
  echo "Passenger: OK"
  echo "Driver: OK"
  echo "Admin: OK"
  echo "================================"
else
  echo "DADIA STAGE 2: FAILED"
  echo "BACKUP: $BACKUP"
  echo "================================"
  exit 1
fi
