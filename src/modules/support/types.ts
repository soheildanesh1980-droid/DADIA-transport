export type SupportStatus =
  | "open"
  | "in_progress"
  | "closed";

export type SupportPriority =
  | "low"
  | "normal"
  | "high"
  | "urgent";

export interface CreateSupportTicketInput {
  userId: string;
  subject: string;
  message: string;
  priority?: SupportPriority;
}
