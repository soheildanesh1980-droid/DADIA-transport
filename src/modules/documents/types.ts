export type DocumentStatus =
  | "pending"
  | "approved"
  | "rejected"
  | "expired";

export interface CreateDriverDocumentInput {
  driverId: string;
  documentType: string;
  documentNumber?: string | null;
  countryCode?: string | null;
  issuedAt?: string | null;
  expiresAt?: string | null;
  metadata?: Record<string, unknown>;
}

export interface CreateVehicleDocumentInput {
  vehicleId: string;
  documentType: string;
  documentNumber?: string | null;
  countryCode?: string | null;
  issuedAt?: string | null;
  expiresAt?: string | null;
  metadata?: Record<string, unknown>;
}
