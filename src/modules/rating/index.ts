import { Router } from "express";
import {
  getAuthUser,
  requireAuth
} from "../../middleware/auth.js";
import {
  createRating,
  getUserRatings,
  getMyRatings
} from "./service.js";

const router = Router();

router.use(requireAuth);

router.post("/", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const rating = await createRating({
      raterId: auth.sub,
      ratedUserId: String(req.body.ratedUserId ?? ""),
      tripId: req.body.tripId ?? null,
      score: Number(req.body.score),
      comment: req.body.comment ?? null
    });

    return res.status(201).json({
      ok: true,
      rating
    });
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "rating_error"
    });
  }
});

router.get("/me", async (req, res) => {
  try {
    const auth = getAuthUser(req);

    const ratings = await getMyRatings(auth.sub);

    return res.json({
      ok: true,
      ratings
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "rating_error"
    });
  }
});

router.get("/user/:userId", async (req, res) => {
  try {
    const result = await getUserRatings(req.params.userId);

    return res.json({
      ok: true,
      ...result
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error:
        error instanceof Error
          ? error.message
          : "rating_error"
    });
  }
});

export default router;
