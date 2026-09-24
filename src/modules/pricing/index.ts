import { Router } from "express";
import { listCurrencies } from "./currencies.js";
import { PRICING_CATALOG } from "./catalog.js";
import { requireAuth } from "../../middleware/auth.js";
import {
  calculateFare,
  getPricingServices
} from "./engine.js";

const router = Router();

router.get(
  "/currencies",
  requireAuth,
  async (_req, res) => {
    const currencies = listCurrencies().map((currency) => ({
      ...currency,
      pricingConfigured:
        Object.keys(PRICING_CATALOG[currency.code] ?? {}).length > 0
    }));

    return res.json({
      ok: true,
      currencies
    });
  }
);

router.get(
  "/services",
  requireAuth,
  async (_req, res) => {
    return res.json({
      ok: true,
      pricingVersion: 1,
      services: getPricingServices()
    });
  }
);

router.post(
  "/calculate",
  requireAuth,
  async (req, res) => {
    try {
      const {
        serviceType,
        vehicleType,
        distanceKm,
        durationMin,
        currency
      } = req.body ?? {};

      if (
        typeof serviceType !== "string" ||
        !Number.isFinite(Number(distanceKm)) ||
        !Number.isFinite(Number(durationMin))
      ) {
        return res.status(400).json({
          ok: false,
          error: "invalid_pricing_input"
        });
      }

      const result = calculateFare({
        serviceType,
        vehicleType:
          vehicleType === undefined
            ? null
            : vehicleType,
        distanceKm: Number(distanceKm),
        durationMin: Number(durationMin),
        currency: typeof currency === "string" ? currency : "IRR"
      });

      return res.json({
        ok: true,
        pricing: result
      });
    } catch (error: any) {
      if (
        error instanceof Error &&
        error.message === "unsupported_service_type"
      ) {
        return res.status(400).json({
          ok: false,
          error: "unsupported_service_type"
        });
      }

      if (error instanceof Error && error.message === "unsupported_currency") {
        return res.status(400).json({
          ok: false,
          error: "unsupported_currency"
        });
      }

      if (error instanceof Error && error.message === "pricing_currency_not_configured") {
        return res.status(400).json({
          ok: false,
          error: "pricing_currency_not_configured"
        });
      }

      if (
        error instanceof Error &&
        error.message === "invalid_pricing_input"
      ) {
        return res.status(400).json({
          ok: false,
          error: "invalid_pricing_input"
        });
      }

      console.error(error);

      return res.status(500).json({
        ok: false,
        error: "internal_error"
      });
    }
  }
);

export default router;
