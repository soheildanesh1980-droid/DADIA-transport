import { Router } from "express";
import { getAuthUser, requireAuth } from "../../middleware/auth.js";
import {
  createPickupOrder,
  getPassengerPickupOrders
} from "./service.js";

const router = Router();

router.post("/", requireAuth, async (req, res) => {
  try {
    const body = req.body ?? {};

    const order = await createPickupOrder({
      passengerId: getAuthUser(req).sub,

      originAddress: String(body.originAddress ?? ""),
      destinationAddress: String(body.destinationAddress ?? ""),

      originLat: Number(body.originLat),
      originLng: Number(body.originLng),
      destinationLat: Number(body.destinationLat),
      destinationLng: Number(body.destinationLng),

      cargoType:
        typeof body.cargoType === "string" ? body.cargoType : null,

      cargoDescription:
        typeof body.cargoDescription === "string"
          ? body.cargoDescription
          : null,

      weightKg:
        body.weightKg === undefined || body.weightKg === null
          ? null
          : Number(body.weightKg),

      volumeM3:
        body.volumeM3 === undefined || body.volumeM3 === null
          ? null
          : Number(body.volumeM3),

      vehicleType:
        typeof body.vehicleType === "string"
          ? body.vehicleType
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
        "invalid_volume"
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
    const orders = await getPassengerPickupOrders(
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
