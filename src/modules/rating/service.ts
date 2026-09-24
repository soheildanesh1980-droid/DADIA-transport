import { pool } from "../../database/postgres.js";
import type { CreateRatingInput } from "./types.js";

export async function createRating(input: CreateRatingInput) {
  if (!Number.isInteger(input.score) ||
      input.score < 1 ||
      input.score > 5) {
    throw new Error("invalid_rating_score");
  }

  if (input.raterId === input.ratedUserId) {
    throw new Error("cannot_rate_self");
  }

  const result = await pool.query(
    `INSERT INTO ratings
      (rater_id, rated_user_id, trip_id, score, comment)
     VALUES ($1,$2,$3,$4,$5)
     RETURNING *`,
    [
      input.raterId,
      input.ratedUserId,
      input.tripId ?? null,
      input.score,
      input.comment ?? null
    ]
  );

  return result.rows[0];
}

export async function getUserRatings(userId: string) {
  const result = await pool.query(
    `SELECT *
       FROM ratings
      WHERE rated_user_id = $1
      ORDER BY created_at DESC`,
    [userId]
  );

  const summary = await pool.query(
    `SELECT
       COUNT(*)::int AS count,
       COALESCE(AVG(score),0) AS average
       FROM ratings
      WHERE rated_user_id = $1`,
    [userId]
  );

  return {
    ratings: result.rows,
    summary: summary.rows[0]
  };
}

export async function getMyRatings(userId: string) {
  const result = await pool.query(
    `SELECT *
       FROM ratings
      WHERE rater_id = $1
      ORDER BY created_at DESC`,
    [userId]
  );

  return result.rows;
}
