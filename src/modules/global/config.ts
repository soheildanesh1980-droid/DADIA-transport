export interface CountryConfig {
  code: string;
  name: string;
  defaultCurrency: string;
  languages: string[];
  enabled: boolean;
}

export const COUNTRIES: Record<string, CountryConfig> = {
  IR: { code: "IR", name: "Iran", defaultCurrency: "IRR", languages: ["fa", "en"], enabled: true },
  TR: { code: "TR", name: "Turkey", defaultCurrency: "TRY", languages: ["tr", "en"], enabled: true },
  AZ: { code: "AZ", name: "Azerbaijan", defaultCurrency: "AZN", languages: ["az", "en"], enabled: true },
  AM: { code: "AM", name: "Armenia", defaultCurrency: "AMD", languages: ["hy", "en"], enabled: true },
  AE: { code: "AE", name: "United Arab Emirates", defaultCurrency: "AED", languages: ["ar", "en"], enabled: true },
  IQ: { code: "IQ", name: "Iraq", defaultCurrency: "IQD", languages: ["ar", "en"], enabled: true }
};

export function listCountries(): CountryConfig[] {
  return Object.values(COUNTRIES);
}

export function getCountry(code: string): CountryConfig | null {
  return COUNTRIES[code.toUpperCase()] ?? null;
}

export const LANGUAGES = [
  { code: "fa", name: "Persian" },
  { code: "en", name: "English" },
  { code: "tr", name: "Turkish" },
  { code: "az", name: "Azerbaijani" },
  { code: "hy", name: "Armenian" },
  { code: "ar", name: "Arabic" }
];
