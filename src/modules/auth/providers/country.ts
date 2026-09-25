export const SUPPORTED_SMS_COUNTRIES = {
  IR: "+98",
  AM: "+374",
  AZ: "+994",
  TR: "+90",
  AE: "+971",
  IQ: "+964",
} as const;

export type SmsCountry =
  keyof typeof SUPPORTED_SMS_COUNTRIES;

export function getSmsCountry(
  phone: string,
): SmsCountry | null {
  const normalized = String(phone).trim();

  for (const [
    country,
    prefix,
  ] of Object.entries(
    SUPPORTED_SMS_COUNTRIES,
  ) as [SmsCountry, string][]) {
    if (normalized.startsWith(prefix)) {
      return country;
    }
  }

  return null;
}
