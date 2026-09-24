import Telnyx from "telnyx";
import type { SmsProvider } from "./sms.js";

export class TelnyxSmsProvider implements SmsProvider {
  readonly name = "telnyx";

  private readonly client: Telnyx;
  private readonly fromNumber: string;

  constructor() {
    const apiKey = process.env.TELNYX_API_KEY;
    const fromNumber = process.env.TELNYX_FROM_NUMBER;

    if (!apiKey) {
      throw new Error("TELNYX_API_KEY_NOT_CONFIGURED");
    }

    if (!fromNumber) {
      throw new Error("TELNYX_FROM_NUMBER_NOT_CONFIGURED");
    }

    this.client = new Telnyx({ apiKey });
    this.fromNumber = fromNumber;
  }

  async sendOtp(input: {
    phone: string;
    code: string;
    locale?: string;
  }) {
    const message = await this.client.messages.send({
      from: this.fromNumber,
      to: input.phone,
      text: `DADIA verification code: ${input.code}`,
    });

    return {
      success: true,
      providerMessageId: message.data?.id,
    };
  }
}
