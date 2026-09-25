import type { SmsProvider } from "./sms.js";
import { CountryHttpSmsProvider } from "./http-json.js";
import {
  getSmsCountry,
  type SmsCountry,
} from "./country.js";

function providerName(
  country: SmsCountry,
): string {
  return String(
    process.env[
      `SMS_PROVIDER_${country}`
    ] ?? "none",
  ).toLowerCase();
}

export function getSmsProvider(
  phone: string,
): SmsProvider | null {
  const country =
      getSmsCountry(phone);

  if (!country) {
    return null;
  }

  const provider =
      providerName(country);

  if (
      provider === "none" ||
      provider === "") {
    return null;
  }

  if (
      provider === "http-json" ||
      provider === "http_json"
  ) {
    return new CountryHttpSmsProvider(
      country,
    );
  }

  throw new Error(
    `sms_provider_not_configured:${country}:${provider}`,
  );
}
