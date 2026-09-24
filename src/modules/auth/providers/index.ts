import type { SmsProvider } from "./sms.js";
import { TelnyxSmsProvider } from "./telnyx.js";

export function getSmsProvider(): SmsProvider | null {
  const provider = String(process.env.SMS_PROVIDER ?? "none").toLowerCase();

  if (provider === "none") {
    return null;
  }

  if (provider === "telnyx") {
    return new TelnyxSmsProvider();
  }

  throw new Error(`sms_provider_not_configured:${provider}`);
}
