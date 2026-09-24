export type HeavyTruckStatus =
  | "requested"
  | "searching"
  | "accepted"
  | "arriving"
  | "loading"
  | "in_transit"
  | "delivered"
  | "cancelled";

export interface CreateHeavyTruckOrderInput {
  passengerId: string;
  originAddress: string;
  destinationAddress: string;
  originLat: number;
  originLng: number;
  destinationLat: number;
  destinationLng: number;

  cargoType?: string | null;
  cargoDescription?: string | null;

  weightTon?: number | null;
  volumeM3?: number | null;

  vehicleType?: string | null;
  truckType?: string | null;

  axleCount?: number | null;
  requiresTrailer?: boolean | null;
  trailerType?: string | null;

  loadingType?: string | null;
  specialRequirements?: string | null;

  recipientName?: string | null;
  recipientPhone?: string | null;
  passengerPhone?: string | null;

  countryCode?: string;
  currency?: string;
}
