ALTER TYPE payment_status
  ADD VALUE IF NOT EXISTS 'processing';

ALTER TYPE payment_status
  ADD VALUE IF NOT EXISTS 'cancelled';
