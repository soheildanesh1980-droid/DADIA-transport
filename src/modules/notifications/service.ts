import { pool } from "../../database/postgres.js";
import {
  getNotificationProvider
} from "./providers/index.js";
import type {
  NotificationRequest,
  NotificationChannel
} from "./types.js";

export async function sendNotification(
  request: NotificationRequest
) {
  const provider = getNotificationProvider("mock");

  if (!provider) {
    throw new Error("notification_provider_not_configured");
  }

  const inserted = await pool.query(
    `INSERT INTO notifications
      (user_id, channel, title, message, data, status)
     VALUES ($1,$2,$3,$4,$5,'pending')
     RETURNING *`,
    [
      request.userId,
      request.channel,
      request.title,
      request.message,
      JSON.stringify(request.data ?? {})
    ]
  );

  const result = await provider.send(request);

  const updated = await pool.query(
    `UPDATE notifications
        SET status = $1,
            sent_at = NOW()
      WHERE id = $2
      RETURNING *`,
    [result.status, inserted.rows[0].id]
  );

  return updated.rows[0];
}

export async function getUserNotifications(
  userId: string
) {
  const result = await pool.query(
    `SELECT *
       FROM notifications
      WHERE user_id = $1
      ORDER BY created_at DESC`,
    [userId]
  );

  return result.rows;
}

export async function markNotificationRead(
  userId: string,
  id: string
) {
  const result = await pool.query(
    `UPDATE notifications
        SET status = 'read',
            read_at = NOW()
      WHERE id = $1
        AND user_id = $2
      RETURNING *`,
    [id, userId]
  );

  return result.rows[0] ?? null;
}
