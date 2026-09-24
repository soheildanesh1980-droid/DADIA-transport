export type PaymentStatus =
  | "pending"
  | "processing"
  | "paid"
  | "failed"
  | "cancelled"
  | "refunded";

export interface PaymentRequest {
  paymentId: string;
  amount: number;
  currency: string;
  description?: string;
  returnUrl?: string;
  metadata?: Record<string, string>;
}

export interface PaymentInitiationResult {
  provider: string;
  status: PaymentStatus;
  transactionId: string | null;
  paymentUrl: string | null;
  providerReference: string | null;
}

export interface PaymentVerificationResult {
  provider: string;
  status: PaymentStatus;
  transactionId: string | null;
  providerReference: string | null;
}

export interface PaymentProvider {
  readonly name: string;

  initiate(request: PaymentRequest): Promise<PaymentInitiationResult>;

  verify(
    transactionId: string
  ): Promise<PaymentVerificationResult>;

  refund(
    transactionId: string,
    amount?: number
  ): Promise<PaymentVerificationResult>;
}
