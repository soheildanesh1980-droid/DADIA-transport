import { Router } from "express";
import {
  getAuthUser,
  requireAuth
} from "../../middleware/auth.js";
import {
  createDriverDocument,
  getDriverDocuments,
  createVehicleDocument,
  getVehicleDocuments
} from "./service.js";
import { pool } from "../../database/postgres.js";

const router = Router();

router.use(requireAuth);

router.post("/driver", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const document = await createDriverDocument({
      driverId: auth.sub,
      documentType: String(req.body.documentType ?? ""),
      documentNumber: req.body.documentNumber ?? null,
      countryCode: req.body.countryCode ?? null,
      issuedAt: req.body.issuedAt ?? null,
      expiresAt: req.body.expiresAt ?? null,
      metadata: req.body.metadata ?? {}
    });

    return res.status(201).json({
      ok: true,
      document
    });
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "document_error"
    });
  }
});

router.get("/driver/me", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const documents =
      await getDriverDocuments(auth.sub);

    return res.json({
      ok: true,
      documents
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "document_error"
    });
  }
});

router.post("/vehicle/:vehicleId", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const ownership = await pool.query(
      `SELECT id
         FROM vehicles
        WHERE id = $1
          AND driver_id = $2`,
      [req.params.vehicleId, auth.sub]
    );

    if (ownership.rowCount === 0) {
      return res.status(404).json({
        ok: false,
        error: "vehicle_not_found"
      });
    }

    const document = await createVehicleDocument({
      vehicleId: req.params.vehicleId,
      documentType: String(req.body.documentType ?? ""),
      documentNumber: req.body.documentNumber ?? null,
      countryCode: req.body.countryCode ?? null,
      issuedAt: req.body.issuedAt ?? null,
      expiresAt: req.body.expiresAt ?? null,
      metadata: req.body.metadata ?? {}
    });

    return res.status(201).json({
      ok: true,
      document
    });
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "document_error"
    });
  }
});

router.get("/vehicle/:vehicleId", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const ownership = await pool.query(
      `SELECT id
         FROM vehicles
        WHERE id = $1
          AND driver_id = $2`,
      [req.params.vehicleId, auth.sub]
    );

    if (ownership.rowCount === 0) {
      return res.status(404).json({
        ok: false,
        error: "vehicle_not_found"
      });
    }

    const documents =
      await getVehicleDocuments(req.params.vehicleId);

    return res.json({
      ok: true,
      documents
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "document_error"
    });
  }
});

export default router;
