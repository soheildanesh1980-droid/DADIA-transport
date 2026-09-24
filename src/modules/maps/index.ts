import express from "express";
import { requireAuth } from "../../middleware/auth.js";
import { HaversineMapProvider } from "./haversine.js";
import type { Coordinates } from "./types.js";

const router = express.Router();
const provider = new HaversineMapProvider();

function parseCoordinates(body: any): {
  origin: Coordinates;
  destination: Coordinates;
} {
  const origin = {
    latitude: Number(body?.origin?.latitude),
    longitude: Number(body?.origin?.longitude)
  };

  const destination = {
    latitude: Number(body?.destination?.latitude),
    longitude: Number(body?.destination?.longitude)
  };

  for (const point of [origin, destination]) {
    if (
      !Number.isFinite(point.latitude) ||
      !Number.isFinite(point.longitude) ||
      point.latitude < -90 ||
      point.latitude > 90 ||
      point.longitude < -180 ||
      point.longitude > 180
    ) {
      throw new Error("invalid_coordinates");
    }
  }

  return { origin, destination };
}

router.get("/providers", requireAuth, async (_req, res) => {
  return res.json({
    ok: true,
    active_provider: provider.name,
    providers: [
      {
        name: provider.name,
        type: "local",
        replaceable: true
      }
    ]
  });
});

router.post("/route-estimate", requireAuth, async (req, res) => {
  try {
    const { origin, destination } = parseCoordinates(req.body);

    const route = provider.estimateRoute(origin, destination);

    return res.json({
      ok: true,
      route
    });
  } catch (error) {
    if (
      error instanceof Error &&
      error.message === "invalid_coordinates"
    ) {
      return res.status(400).json({
        ok: false,
        error: "invalid_coordinates"
      });
    }

    console.error(error);

    return res.status(500).json({
      ok: false,
      error: "internal_error"
    });
  }
});

export default router;
