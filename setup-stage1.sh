#!/data/data/com.termux/files/usr/bin/bash
set -e

mkdir -p src/{config,modules/{passenger,driver,admin},routes,middleware}

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "rootDir": "src",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*.ts"]
}
JSON

cat > src/config/env.ts <<'TS'
export const env = {
  port: Number(process.env.PORT ?? 3000),
  nodeEnv: process.env.NODE_ENV ?? "development"
};
TS

cat > src/routes/health.ts <<'TS'
import { Router } from "express";

const router = Router();

router.get("/", (_req, res) => {
  res.json({
    status: "ok",
    service: "DADIA Transport API",
    version: "1.0.0",
    backend: true,
    timestamp: new Date().toISOString()
  });
});

export default router;
TS

cat > src/modules/passenger/index.ts <<'TS'
export const passengerModule = {
  name: "passenger",
  status: "initialized"
};
TS

cat > src/modules/driver/index.ts <<'TS'
export const driverModule = {
  name: "driver",
  status: "initialized"
};
TS

cat > src/modules/admin/index.ts <<'TS'
export const adminModule = {
  name: "admin",
  status: "initialized"
};
TS

cat > src/app.ts <<'TS'
import express from "express";
import healthRouter from "./routes/health.js";

const app = express();

app.use(express.json());

app.get("/", (_req, res) => {
  res.json({
    name: "DADIA Transport",
    status: "running",
    api: "REST"
  });
});

app.use("/health", healthRouter);

export default app;
TS

cat > src/server.ts <<'TS'
import app from "./app.js";
import { env } from "./config/env.js";

app.listen(env.port, "0.0.0.0", () => {
  console.log(`DADIA Transport API running on http://0.0.0.0:${env.port}`);
});
TS

node -e '
const fs=require("fs");
const p=JSON.parse(fs.readFileSync("package.json","utf8"));
p.type="module";
p.main="dist/server.js";
p.scripts={
  dev:"tsx watch src/server.ts",
  build:"tsc",
  start:"node dist/server.js",
  typecheck:"tsc --noEmit"
};
fs.writeFileSync("package.json",JSON.stringify(p,null,2)+"\n");
'

npm install express
npm install --save-dev @types/express

npm run typecheck
npm run build

echo
echo "================================"
echo "DADIA STAGE 1 BUILD: PASS"
echo "================================"
echo
find src -type f | sort
