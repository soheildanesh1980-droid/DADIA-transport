export interface CurrencyConfig {
  code: string;
  name: string;
  symbol: string;
  country: string;
}

export const CURRENCIES: Record<string, CurrencyConfig> = {
  IRR: { code: "IRR", name: "Iranian Rial", symbol: "﷼", country: "IR" },
  USD: { code: "USD", name: "US Dollar", symbol: "$", country: "US" },
  EUR: { code: "EUR", name: "Euro", symbol: "€", country: "EU" },
  GBP: { code: "GBP", name: "British Pound", symbol: "£", country: "GB" },
  AZN: { code: "AZN", name: "Azerbaijani Manat", symbol: "₼", country: "AZ" },
  TRY: { code: "TRY", name: "Turkish Lira", symbol: "₺", country: "TR" },
  AMD: { code: "AMD", name: "Armenian Dram", symbol: "֏", country: "AM" },
  AED: { code: "AED", name: "UAE Dirham", symbol: "د.إ", country: "AE" },
  IQD: { code: "IQD", name: "Iraqi Dinar", symbol: "ع.د", country: "IQ" }
};

export function getCurrency(code: string): CurrencyConfig | null {
  return CURRENCIES[code.toUpperCase()] ?? null;
}

export function listCurrencies(): CurrencyConfig[] {
  return Object.values(CURRENCIES);
}
