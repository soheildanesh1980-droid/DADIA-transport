import { Router } from "express";
import {
  getAuthUser,
  requireAuth
} from "../../middleware/auth.js";
import {
  createSupportTicket,
  getUserSupportTickets
} from "./service.js";

const router = Router();

router.use(requireAuth);

router.post("/", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const ticket = await createSupportTicket({
      userId: auth.sub,
      subject: String(req.body.subject ?? ""),
      message: String(req.body.message ?? ""),
      priority: req.body.priority
    });

    return res.status(201).json({
      ok: true,
      ticket
    });
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "support_error"
    });
  }
});

router.get("/me", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const tickets =
      await getUserSupportTickets(auth.sub);

    return res.json({
      ok: true,
      tickets
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "support_error"
    });
  }
});

export default router;
