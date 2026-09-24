import { Router } from "express";
import {
  getAuthUser,
  requireAuth
} from "../../middleware/auth.js";
import {
  createVehicle,
  getDriverVehicles
} from "./service.js";

const router = Router();

router.use(requireAuth);

router.post("/", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const vehicle = await createVehicle({
      driverId: auth.sub,
      vehicleType: String(req.body.vehicleType ?? ""),
      make: req.body.make ?? null,
      model: req.body.model ?? null,
      modelYear:
        req.body.modelYear === undefined
          ? null
          : Number(req.body.modelYear),
      color: req.body.color ?? null,
      plateNumber: req.body.plateNumber ?? null,
      countryCode: req.body.countryCode ?? null
    });

    return res.status(201).json({
      ok: true,
      vehicle
    });
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "vehicle_error"
    });
  }
});

router.get("/me", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const vehicles = await getDriverVehicles(auth.sub);

    return res.json({
      ok: true,
      vehicles
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "vehicle_error"
    });
  }
});

export default router;
