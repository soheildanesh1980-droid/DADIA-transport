import { Router } from "express";
import { requireAuth, requireRole } from "../middleware/auth.js";

const router = Router();

router.get("/passenger-only", requireAuth, requireRole("passenger"), (req, res) => {
  res.json({ ok: true, message: "Passenger access granted", user: req.authUser });
});

router.get("/driver-only", requireAuth, requireRole("driver"), (req, res) => {
  res.json({ ok: true, message: "Driver access granted", user: req.authUser });
});

router.get("/admin-only", requireAuth, requireRole("admin"), (req, res) => {
  res.json({ ok: true, message: "Admin access granted", user: req.authUser });
});

export default router;
