import { Router } from "express";
import { getAuthUser, requireAuth } from "../../middleware/auth.js";
import {
  createMovingOrder,
  getPassengerMovingOrders
} from "./service.js";

const router = Router();

router.post("/", requireAuth, async (req, res) => {
  try {
    const body = req.body ?? {};

    const order = await createMovingOrder({
      passengerId: getAuthUser(req).sub,

      originAddress: String(body.originAddress ?? ""),
      destinationAddress: String(body.destinationAddress ?? ""),

      originLat: Number(body.originLat),
      originLng: Number(body.originLng),
      destinationLat: Number(body.destinationLat),
      destinationLng: Number(body.destinationLng),

      moveType:
        typeof body.moveType === "string"
          ? body.moveType
          : null,

      description:
        typeof body.description === "string"
          ? body.description
          : null,

      estimatedWeightKg:
        body.estimatedWeightKg === undefined ||
        body.estimatedWeightKg === null
          ? null
          : Number(body.estimatedWeightKg),

      estimatedVolumeM3:
        body.estimatedVolumeM3 === undefined ||
        body.estimatedVolumeM3 === null
          ? null
          : Number(body.estimatedVolumeM3),

      vehicleType:
        typeof body.vehicleType === "string"
          ? body.vehicleType
          : null,

      helperCount:
        body.helperCount === undefined ||
        body.helperCount === null
          ? null
          : Number(body.helperCount),

      movingDate:
        typeof body.movingDate === "string"
          ? body.movingDate
          : null,

      movingTime:
        typeof body.movingTime === "string"
          ? body.movingTime
          : null,

      recipientName:
        typeof body.recipientName === "string"
          ? body.recipientName
          : null,

      recipientPhone:
        typeof body.recipientPhone === "string"
          ? body.recipientPhone
          : null,

      passengerPhone:
        typeof body.passengerPhone === "string"
          ? body.passengerPhone
          : null,

      countryCode:
        typeof body.countryCode === "string"
          ? body.countryCode
          : "IR",

      currency:
        typeof body.currency === "string"
          ? body.currency
          : "IRR"
    });

    return res.status(201).json({
      ok: true,
      order
    });
  } catch (error) {
    if (error instanceof Error) {
      const known = new Set([
        "invalid_address",
        "invalid_coordinates",
        "invalid_weight",
        "invalid_volume",
        "invalid_helper_count"
      ]);

      if (known.has(error.message)) {
        return res.status(400).json({
          ok: false,
          error: error.message
        });
      }
    }

    console.error(error);

    return res.status(500).json({
      ok: false,
      error: "internal_error"
    });
  }
});

router.get("/me", requireAuth, async (req, res) => {
  try {
    const orders = await getPassengerMovingOrders(
      getAuthUser(req).sub
    );

    return res.json({
      ok: true,
      orders
    });
  } catch (error) {
    console.error(error);

    return res.status(500).json({
      ok: false,
      error: "internal_error"
    });
  }
});

export default router;
