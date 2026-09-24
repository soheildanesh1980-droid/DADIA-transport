ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS currency VARCHAR(10) NOT NULL DEFAULT 'IRR';

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS description TEXT;

CREATE INDEX IF NOT EXISTS idx_payments_currency
  ON payments(currency);
