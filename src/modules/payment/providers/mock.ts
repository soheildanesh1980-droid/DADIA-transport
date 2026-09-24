import type {
  PaymentProvider,
  PaymentRequest,
  PaymentInitiationResult,
  PaymentVerificationResult
} from "../types.js";

export class MockPaymentProvider implements PaymentProvider {
  readonly name = "mock";

  async initiate(
    request: PaymentRequest
  ): Promise<PaymentInitiationResult> {
    const transactionId = `mock_${request.paymentId}`;

    return {
      provider: this.name,
      status: "processing",
      transactionId,
      paymentUrl: null,
      providerReference: transactionId
    };
  }

  async verify(
    transactionId: string
  ): Promise<PaymentVerificationResult> {
    return {
      provider: this.name,
      status: "paid",
      transactionId,
      providerReference: transactionId
    };
  }

  async refund(
    transactionId: string
  ): Promise<PaymentVerificationResult> {
    return {
      provider: this.name,
      status: "refunded",
      transactionId,
      providerReference: transactionId
    };
  }
}
