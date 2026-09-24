import { Router } from "express";
import { requireAuth, getAuthUser } from "../../middleware/auth.js";
import {
  createPayment,
  verifyPayment,
  refundPayment
} from "./service.js";
import {
  listPaymentProviders
} from "./providers/index.js";

const router = Router();

router.get(
  "/providers",
  requireAuth,
  async (_req, res) => {
    return res.json({
      ok: true,
      providers: listPaymentProviders()
    });
  }
);

router.post(
  "/create",
  requireAuth,
  async (req, res) => {
    try {
      const {
        amount,
        currency,
        description
      } = req.body ?? {};

      const result = await createPayment({
        userId: getAuthUser(req).sub,
        amount: Number(amount),
        currency:
          typeof currency === "string"
            ? currency
            : "IRR",
        description:
          typeof description === "string"
            ? description
            : undefined
      });

      return res.status(201).json({
        ok: true,
        payment: result
      });
    } catch (error: any) {
      if (error instanceof Error) {
        const knownErrors = new Set([
          "invalid_payment_amount",
          "invalid_payment_currency",
          "payment_provider_unavailable"
        ]);

        if (knownErrors.has(error.message)) {
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
  }
);

router.post(
  "/:id/verify",
  requireAuth,
  async (req, res) => {
    try {
      const result = await verifyPayment(
        getAuthUser(req).sub,
        String(req.params.id)
      );

      return res.json({
        ok: true,
        payment: result
      });
    } catch (error: any) {
      if (error instanceof Error) {
        const statusMap: Record<string, number> = {
          payment_not_found: 404,
          payment_forbidden: 403,
          payment_transaction_not_found: 400,
          payment_provider_unavailable: 400
        };

        const status =
          statusMap[error.message];

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
  }
);

router.post(
  "/:id/refund",
  requireAuth,
  async (req, res) => {
    try {
      const result = await refundPayment(
        getAuthUser(req).sub,
        String(req.params.id)
      );

      return res.json({
        ok: true,
        payment: result
      });
    } catch (error: any) {
      if (error instanceof Error) {
        const statusMap: Record<string, number> = {
          payment_not_found: 404,
          payment_forbidden: 403,
          payment_not_refundable: 400,
          payment_transaction_not_found: 400,
          payment_provider_unavailable: 400
        };

        const status =
          statusMap[error.message];

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
  }
);

export default router;
