export interface PricingConfig {
  currency: string;
  configured: boolean;
  base: number;
  perKm: number;
  perMinute: number;
  minimum: number;
}

export interface PricingInput {
  serviceType: string;
  vehicleType?: string | null;
  distanceKm: number;
  durationMin: number;
  currency?: string;
}

export interface PricingResult {
  serviceType: string;
  vehicleType: string | null;
  distanceKm: number;
  durationMin: number;
  baseFare: number;
  distanceFare: number;
  durationFare: number;
  minimumFare: number;
  estimatedFare: number;
  pricingVersion: number;
  currency: string;
  currencySymbol: string;
}
