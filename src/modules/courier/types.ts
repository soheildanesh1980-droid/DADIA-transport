export type CourierStatus =
  | "requested"
  | "searching"
  | "accepted"
  | "arriving"
  | "picked_up"
  | "in_transit"
  | "delivered"
  | "cancelled";

export interface CreateCourierOrderInput {
  passengerId: string;
  originAddress: string;
  destinationAddress: string;
  originLat: number;
  originLng: number;
  destinationLat: number;
  destinationLng: number;
  packageDescription?: string | null;
  packageWeightKg?: number | null;
  recipientName?: string | null;
  recipientPhone?: string | null;
  passengerPhone?: string | null;
  countryCode?: string;
  currency?: string;
}

export interface CourierOrder {
  id: string;
  passengerId: string;
  driverId: string | null;
  originAddress: string;
  destinationAddress: string;
  originLat: number;
  originLng: number;
  destinationLat: number;
  destinationLng: number;
  packageDescription: string | null;
  packageWeightKg: number | null;
  recipientName: string | null;
  recipientPhone: string | null;
  passengerPhone: string | null;
  countryCode: string;
  currency: string;
  status: CourierStatus;
  createdAt: string;
  updatedAt: string;
}
