import type {
  NotificationProvider,
  NotificationRequest,
  NotificationResult
} from "../types.js";

export class MockNotificationProvider
  implements NotificationProvider {

  readonly name = "mock";

  async send(
    request: NotificationRequest
  ): Promise<NotificationResult> {
    return {
      id: "",
      userId: request.userId,
      channel: request.channel,
      status: "sent"
    };
  }
}
