export interface SmsProvider {
  readonly name: string;

  sendOtp(input: {
    phone: string;
    code: string;
    locale?: string;
  }): Promise<{
    success: boolean;
    providerMessageId?: string;
  }>;
}
