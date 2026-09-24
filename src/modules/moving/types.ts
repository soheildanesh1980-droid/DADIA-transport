export type MovingStatus =
  | "requested"
  | "searching"
  | "accepted"
  | "arriving"
  | "loading"
  | "in_transit"
  | "delivered"
  | "cancelled";

export interface CreateMovingOrderInput {
  passengerId: string;

  originAddress: string;
  destinationAddress: string;

  originLat: number;
  originLng: number;
  destinationLat: number;
  destinationLng: number;

  moveType?: string | null;
  description?: string | null;

  estimatedWeightKg?: number | null;
  estimatedVolumeM3?: number | null;

  vehicleType?: string | null;
  helperCount?: number | null;

  movingDate?: string | null;
  movingTime?: string | null;

  recipientName?: string | null;
  recipientPhone?: string | null;
  passengerPhone?: string | null;

  countryCode?: string;
  currency?: string;
}

export interface MovingOrder {
  id: string;
  passengerId: string;
  driverId: string | null;

  originAddress: string;
  destinationAddress: string;

  originLat: number;
  originLng: number;
  destinationLat: number;
  destinationLng: number;

  moveType: string | null;
  description: string | null;

  estimatedWeightKg: number | null;
  estimatedVolumeM3: number | null;

  vehicleType: string | null;
  helperCount: number | null;

  movingDate: string | null;
  movingTime: string | null;

  recipientName: string | null;
  recipientPhone: string | null;
  passengerPhone: string | null;

  countryCode: string;
  currency: string;
  status: MovingStatus;

  createdAt: string;
  updatedAt: string;
}
