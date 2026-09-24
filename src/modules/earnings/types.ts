export interface CreateEarningInput {
  driverId: string;
  tripId?: string | null;
  grossAmount: number;
  platformFee?: number;
  currency?: string;
  description?: string;
}

export interface SettlementInput {
  driverId: string;
  amount: number;
  currency?: string;
}
