import { Router } from "express";
import {
  getAuthUser,
  requireAuth
} from "../../middleware/auth.js";
import {
  sendNotification,
  getUserNotifications,
  markNotificationRead
} from "./service.js";
import {
  listNotificationProviders
} from "./providers/index.js";

const router = Router();

router.use(requireAuth);

router.get("/providers", (_req, res) => {
  res.json({
    ok: true,
    providers: listNotificationProviders()
  });
});

router.get("/me", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const notifications =
      await getUserNotifications(auth.sub);

    res.json({
      ok: true,
      notifications
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "notification_error"
    });
  }
});

router.post("/", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const notification =
      await sendNotification({
        userId: auth.sub,
        channel: req.body.channel ?? "in_app",
        title: String(req.body.title ?? ""),
        message: String(req.body.message ?? ""),
        data: req.body.data ?? {}
      });

    res.status(201).json({
      ok: true,
      notification
    });
  } catch (error) {
    res.status(400).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "notification_error"
    });
  }
});

router.post("/:id/read", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const notification =
      await markNotificationRead(
        auth.sub,
        req.params.id
      );

    if (!notification) {
      return res.status(404).json({
        ok: false,
        error: "notification_not_found"
      });
    }

    return res.json({
      ok: true,
      notification
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "notification_error"
    });
  }
});

export default router;
