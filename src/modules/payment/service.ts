import { randomUUID } from "node:crypto";
import { pool } from "../../database/postgres.js";
import {
  getPaymentProvider
} from "./providers/index.js";

export async function createPayment(params: {
  userId: string;
  amount: number;
  currency: string;
  description?: string;
}) {
  const {
    userId,
    amount,
    currency,
    description
  } = params;

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error("invalid_payment_amount");
  }

  const currencyCode = currency.trim().toUpperCase();

  if (!currencyCode) {
    throw new Error("invalid_payment_currency");
  }

  const provider = getPaymentProvider();

  if (!provider) {
    throw new Error("payment_provider_unavailable");
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const paymentId = randomUUID();

    await client.query(
      `INSERT INTO payments
       (id, user_id, amount, currency, status, description)
       VALUES ($1, $2, $3, $4, 'pending', $5)`,
      [
        paymentId,
        userId,
        amount,
        currencyCode,
        description ?? null
      ]
    );

    const initiated = await provider.initiate({
      paymentId,
      amount,
      currency: currencyCode,
      description
    });

    await client.query(
      `INSERT INTO payment_transactions
       (payment_id, provider, transaction_id,
        provider_reference, amount, currency, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        paymentId,
        initiated.provider,
        initiated.transactionId,
        initiated.providerReference,
        amount,
        currencyCode,
        initiated.status
      ]
    );

    await client.query(
      `UPDATE payments
       SET status = $1,
           gateway_transaction_id = $2
       WHERE id = $3`,
      [
        initiated.status,
        initiated.transactionId,
        paymentId
      ]
    );

    await client.query("COMMIT");

    return {
      paymentId,
      provider: initiated.provider,
      status: initiated.status,
      transactionId: initiated.transactionId,
      paymentUrl: initiated.paymentUrl,
      providerReference: initiated.providerReference,
      amount,
      currency: currencyCode
    };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function verifyPayment(
  userId: string,
  paymentId: string
) {
  const result = await pool.query(
    `SELECT
       p.id,
       p.user_id,
       p.amount,
       p.currency,
       p.status,
       pt.provider,
       pt.transaction_id
     FROM payments p
     LEFT JOIN payment_transactions pt
       ON pt.payment_id = p.id
     WHERE p.id = $1
     LIMIT 1`,
    [paymentId]
  );

  if (result.rowCount === 0) {
    throw new Error("payment_not_found");
  }

  const payment = result.rows[0];

  if (payment.user_id !== userId) {
    throw new Error("payment_forbidden");
  }

  if (!payment.transaction_id || !payment.provider) {
    throw new Error("payment_transaction_not_found");
  }

  const provider = getPaymentProvider(payment.provider);

  if (!provider) {
    throw new Error("payment_provider_unavailable");
  }

  const verified = await provider.verify(
    payment.transaction_id
  );

  await pool.query(
    `UPDATE payments
     SET status = $1
     WHERE id = $2`,
    [
      verified.status,
      paymentId
    ]
  );

  await pool.query(
    `UPDATE payment_transactions
     SET status = $1,
         provider_reference = $2,
         updated_at = NOW()
     WHERE payment_id = $3`,
    [
      verified.status,
      verified.providerReference,
      paymentId
    ]
  );

  return {
    paymentId,
    provider: verified.provider,
    status: verified.status,
    transactionId: verified.transactionId,
    providerReference: verified.providerReference
  };
}

export async function refundPayment(
  userId: string,
  paymentId: string
) {
  const result = await pool.query(
    `SELECT
       p.id,
       p.user_id,
       p.status,
       pt.provider,
       pt.transaction_id
     FROM payments p
     LEFT JOIN payment_transactions pt
       ON pt.payment_id = p.id
     WHERE p.id = $1
     LIMIT 1`,
    [paymentId]
  );

  if (result.rowCount === 0) {
    throw new Error("payment_not_found");
  }

  const payment = result.rows[0];

  if (payment.user_id !== userId) {
    throw new Error("payment_forbidden");
  }

  if (payment.status !== "paid") {
    throw new Error("payment_not_refundable");
  }

  if (!payment.transaction_id || !payment.provider) {
    throw new Error("payment_transaction_not_found");
  }

  const provider = getPaymentProvider(payment.provider);

  if (!provider) {
    throw new Error("payment_provider_unavailable");
  }

  const refunded = await provider.refund(
    payment.transaction_id
  );

  await pool.query(
    `UPDATE payments
     SET status = $1
     WHERE id = $2`,
    [
      refunded.status,
      paymentId
    ]
  );

  await pool.query(
    `UPDATE payment_transactions
     SET status = $1,
         updated_at = NOW()
     WHERE payment_id = $2`,
    [
      refunded.status,
      paymentId
    ]
  );

  return {
    paymentId,
    provider: refunded.provider,
    status: refunded.status,
    transactionId: refunded.transactionId,
    providerReference: refunded.providerReference
  };
}
