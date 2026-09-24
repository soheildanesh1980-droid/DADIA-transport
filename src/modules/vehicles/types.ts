export type VehicleStatus =
  | "pending"
  | "approved"
  | "rejected"
  | "inactive";

export interface CreateVehicleInput {
  driverId: string;
  vehicleType: string;
  make?: string | null;
  model?: string | null;
  modelYear?: number | null;
  color?: string | null;
  plateNumber?: string | null;
  countryCode?: string | null;
}
