import type { PricingInput, PricingResult } from "./types.js";
import { getCurrency } from "./currencies.js";

import { PRICING_CATALOG } from "./catalog.js";

const PRICING_VERSION = 1;

export function calculateFare(input: PricingInput): PricingResult {
  const currencyCode = (input.currency ?? "IRR").toUpperCase();
  const currency = getCurrency(currencyCode);

  if (!currency) {
    throw new Error("unsupported_currency");
  }

  const configs = PRICING_CATALOG[currencyCode];

  if (!configs || Object.keys(configs).length === 0) {
    throw new Error("pricing_currency_not_configured");
  }

  const config = configs[input.serviceType];

  if (!config) {
    throw new Error("unsupported_service_type");
  }

  if (
    !Number.isFinite(input.distanceKm) ||
    !Number.isFinite(input.durationMin) ||
    input.distanceKm < 0 ||
    input.durationMin < 0
  ) {
    throw new Error("invalid_pricing_input");
  }

  const baseFare = config.base;
  const distanceFare = Math.round(input.distanceKm * config.perKm);
  const durationFare = Math.round(input.durationMin * config.perMinute);

  const calculated =
    baseFare +
    distanceFare +
    durationFare;

  const estimatedFare = Math.max(
    config.minimum,
    calculated
  );

  return {
    serviceType: input.serviceType,
    vehicleType: input.vehicleType ?? null,
    distanceKm: Number(input.distanceKm.toFixed(3)),
    durationMin: Math.round(input.durationMin),
    baseFare,
    distanceFare,
    durationFare,
    minimumFare: config.minimum,
    estimatedFare,
    pricingVersion: PRICING_VERSION,
    currency: currency.code,
    currencySymbol: currency.symbol
  };
}

export function getPricingServices() {
  const currencyCode = "IRR";
  return Object.entries(PRICING_CATALOG[currencyCode]).map(([serviceType, config]) => ({
    serviceType,
    ...config,
    pricingVersion: PRICING_VERSION
  }));
}
