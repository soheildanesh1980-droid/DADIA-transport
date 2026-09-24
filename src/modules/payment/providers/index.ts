import type { PaymentProvider } from "../types.js";
import { MockPaymentProvider } from "./mock.js";

const providers: Record<string, PaymentProvider> = {
  mock: new MockPaymentProvider()
};

export function getPaymentProvider(
  name = "mock"
): PaymentProvider | null {
  return providers[name] ?? null;
}

export function listPaymentProviders(): string[] {
  return Object.keys(providers);
}
