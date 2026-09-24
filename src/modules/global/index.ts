import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { listCountries, LANGUAGES } from "./config.js";

const router = Router();

router.get("/countries", requireAuth, async (_req, res) => {
  return res.json({
    ok: true,
    countries: listCountries()
  });
});

router.get("/languages", requireAuth, async (_req, res) => {
  return res.json({
    ok: true,
    languages: LANGUAGES
  });
});

export default router;
