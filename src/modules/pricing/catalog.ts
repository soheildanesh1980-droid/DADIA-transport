import type { PricingConfig } from "./types.js";

export type CurrencyPricingCatalog = Record<
  string,
  Record<string, PricingConfig>
>;

export const PRICING_CATALOG: CurrencyPricingCatalog = {
  IRR: {
    ride: { currency: "IRR", configured: true, base: 300000, perKm: 70000, perMinute: 10000, minimum: 500000 },
    courier: { currency: "IRR", configured: true, base: 250000, perKm: 60000, perMinute: 8000, minimum: 400000 },
    pickup: { currency: "IRR", configured: true, base: 500000, perKm: 100000, perMinute: 15000, minimum: 800000 },
    moving: { currency: "IRR", configured: true, base: 1200000, perKm: 150000, perMinute: 25000, minimum: 1800000 },
    truck: { currency: "IRR", configured: true, base: 2500000, perKm: 250000, perMinute: 40000, minimum: 3500000 }
  }
};

for (const currency of ["USD","EUR","GBP","AZN","TRY","AMD","AED","IQD"]) {
  PRICING_CATALOG[currency] = {};
}
