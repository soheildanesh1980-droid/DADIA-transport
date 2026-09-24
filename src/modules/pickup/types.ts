export type PickupStatus =
  | "requested"
  | "searching"
  | "accepted"
  | "arriving"
  | "loading"
  | "in_transit"
  | "delivered"
  | "cancelled";

export interface CreatePickupOrderInput {
  passengerId: string;
  originAddress: string;
  destinationAddress: string;

  originLat: number;
  originLng: number;
  destinationLat: number;
  destinationLng: number;

  cargoType?: string | null;
  cargoDescription?: string | null;
  weightKg?: number | null;
  volumeM3?: number | null;

  vehicleType?: string | null;

  recipientName?: string | null;
  recipientPhone?: string | null;
  passengerPhone?: string | null;

  countryCode?: string;
  currency?: string;
}

export interface PickupOrder {
  id: string;
  passengerId: string;
  driverId: string | null;

  originAddress: string;
  destinationAddress: string;

  originLat: number;
  originLng: number;
  destinationLat: number;
  destinationLng: number;

  cargoType: string | null;
  cargoDescription: string | null;
  weightKg: number | null;
  volumeM3: number | null;

  vehicleType: string | null;

  recipientName: string | null;
  recipientPhone: string | null;
  passengerPhone: string | null;

  countryCode: string;
  currency: string;
  status: PickupStatus;

  createdAt: string;
  updatedAt: string;
}
