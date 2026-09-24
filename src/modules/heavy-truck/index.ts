import express from "express";
import { requireAuth, getAuthUser } from "../../middleware/auth.js";
import {
  createHeavyTruckOrder,
  getPassengerHeavyTruckOrders
} from "./service.js";

const router = express.Router();

router.post("/", requireAuth, async (req, res) => {
  try {
    const authUser = getAuthUser(req);

    const order = await createHeavyTruckOrder({
      passengerId: authUser.sub,
      originAddress: req.body?.originAddress,
      destinationAddress: req.body?.destinationAddress,
      originLat: Number(req.body?.originLat),
      originLng: Number(req.body?.originLng),
      destinationLat: Number(req.body?.destinationLat),
      destinationLng: Number(req.body?.destinationLng),

      cargoType: req.body?.cargoType,
      cargoDescription: req.body?.cargoDescription,

      weightTon:
        req.body?.weightTon === undefined ||
        req.body?.weightTon === null
          ? null
          : Number(req.body.weightTon),

      volumeM3:
        req.body?.volumeM3 === undefined ||
        req.body?.volumeM3 === null
          ? null
          : Number(req.body.volumeM3),

      vehicleType: req.body?.vehicleType,
      truckType: req.body?.truckType,

      axleCount:
        req.body?.axleCount === undefined ||
        req.body?.axleCount === null
          ? null
          : Number(req.body.axleCount),

      requiresTrailer:
        req.body?.requiresTrailer === undefined
          ? false
          : Boolean(req.body.requiresTrailer),

      trailerType: req.body?.trailerType,
      loadingType: req.body?.loadingType,
      specialRequirements: req.body?.specialRequirements,

      recipientName: req.body?.recipientName,
      recipientPhone: req.body?.recipientPhone,
      passengerPhone: req.body?.passengerPhone,

      countryCode: req.body?.countryCode ?? "IR",
      currency: req.body?.currency ?? "IRR"
    });

    return res.status(201).json({
      ok: true,
      order
    });
  } catch (error) {
    if (error instanceof Error) {
      const statusMap: Record<string, number> = {
        invalid_address: 400,
        invalid_coordinates: 400,
        invalid_weight: 400,
        invalid_volume: 400,
        invalid_axle_count: 400
      };

      const status = statusMap[error.message];

      if (status) {
        return res.status(status).json({
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
    const authUser = getAuthUser(req);

    const orders = await getPassengerHeavyTruckOrders(
      authUser.sub
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
