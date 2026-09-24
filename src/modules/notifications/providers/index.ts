import type { NotificationProvider } from "../types.js";
import { MockNotificationProvider } from "./mock.js";

const providers: Record<string, NotificationProvider> = {
  mock: new MockNotificationProvider()
};

export function getNotificationProvider(
  name = "mock"
): NotificationProvider | null {
  return providers[name] ?? null;
}

export function listNotificationProviders(): string[] {
  return Object.keys(providers);
}
