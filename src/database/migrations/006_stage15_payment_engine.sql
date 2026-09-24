CREATE TABLE IF NOT EXISTS payment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  provider VARCHAR(50) NOT NULL,
  transaction_id VARCHAR(150),
  provider_reference VARCHAR(150),
  amount NUMERIC(20,2) NOT NULL CHECK (amount > 0),
  currency VARCHAR(10) NOT NULL,
  status payment_status NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_payment
  ON payment_transactions(payment_id);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_transaction
  ON payment_transactions(transaction_id);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_status
  ON payment_transactions(status);
