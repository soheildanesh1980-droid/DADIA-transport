import { pool } from "../../database/postgres.js";
import type {
  CreateSupportTicketInput,
  SupportPriority
} from "./types.js";

const priorities: SupportPriority[] = [
  "low",
  "normal",
  "high",
  "urgent"
];

export async function createSupportTicket(
  input: CreateSupportTicketInput
) {
  if (!input.subject.trim() || !input.message.trim()) {
    throw new Error("support_subject_message_required");
  }

  const priority =
    priorities.includes(input.priority ?? "normal")
      ? input.priority ?? "normal"
      : "normal";

  const result = await pool.query(
    `INSERT INTO support_tickets
      (user_id, subject, message, priority)
     VALUES ($1,$2,$3,$4)
     RETURNING *`,
    [
      input.userId,
      input.subject.trim(),
      input.message.trim(),
      priority
    ]
  );

  return result.rows[0];
}

export async function getUserSupportTickets(userId: string) {
  const result = await pool.query(
    `SELECT *
       FROM support_tickets
      WHERE user_id = $1
      ORDER BY created_at DESC`,
    [userId]
  );

  return result.rows;
}
