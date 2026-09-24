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
