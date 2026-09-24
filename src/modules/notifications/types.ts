export type NotificationChannel =
  | "in_app"
  | "push"
  | "sms"
  | "email";

export type NotificationStatus =
  | "pending"
  | "sent"
  | "failed"
  | "read";

export interface NotificationRequest {
  userId: string;
  channel: NotificationChannel;
  title: string;
  message: string;
  data?: Record<string, unknown>;
}

export interface NotificationResult {
  id: string;
  userId: string;
  channel: NotificationChannel;
  status: NotificationStatus;
}

export interface NotificationProvider {
  readonly name: string;

  send(
    request: NotificationRequest
  ): Promise<NotificationResult>;
}
