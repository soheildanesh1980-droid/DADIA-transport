import { Router } from "express";
import { getAuthUser, requireAuth } from "../../middleware/auth.js";
import {
  createEarning,
  getDriverEarnings,
  createSettlement,
  getDriverSettlements
} from "./service.js";

const router = Router();

router.use(requireAuth);

router.get("/me", async (req, res) => {
  try {
    const auth = getAuthUser(req);
    const data = await getDriverEarnings(auth.sub);
    res.json({ ok: true, ...data });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: error instanceof Error ? error.message : "earnings_error"
    });
  }
});

router.get("/settlements", async (req, res) => {
  try {
    const auth = getAuthUser(req);
    const settlements = await getDriverSettlements(auth.sub);
    res.json({ ok: true, settlements });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: error instanceof Error ? error.message : "settlement_error"
    });
  }
});

router.post("/settlement", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const settlement = await createSettlement({
      driverId: auth.sub,
      amount: Number(req.body.amount),
      currency: req.body.currency ?? "IRR"
    });

    res.status(201).json({
      ok: true,
      settlement
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "settlement_error";

    const status =
      message === "insufficient_available_balance" ||
      message === "invalid_settlement_amount"
        ? 400
        : 500;

    res.status(status).json({
      ok: false,
      error: message
    });
  }
});

router.post("/earning", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const earning = await createEarning({
      driverId: auth.sub,
      tripId: req.body.tripId ?? null,
      grossAmount: Number(req.body.grossAmount),
      platformFee: Number(req.body.platformFee ?? 0),
      currency: req.body.currency ?? "IRR",
      description: req.body.description
    });

    res.status(201).json({
      ok: true,
      earning
    });
  } catch (error) {
    res.status(400).json({
      ok: false,
      error: error instanceof Error ? error.message : "earning_error"
    });
  }
});

export default router;
