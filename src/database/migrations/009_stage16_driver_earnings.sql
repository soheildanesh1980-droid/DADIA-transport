CREATE TABLE IF NOT EXISTS driver_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
  gross_amount NUMERIC(20,2) NOT NULL CHECK (gross_amount >= 0),
  platform_fee NUMERIC(20,2) NOT NULL DEFAULT 0 CHECK (platform_fee >= 0),
  net_amount NUMERIC(20,2) NOT NULL CHECK (net_amount >= 0),
  currency VARCHAR(10) NOT NULL DEFAULT 'IRR',
  status VARCHAR(30) NOT NULL DEFAULT 'pending',
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  settled_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_driver_earnings_driver
  ON driver_earnings(driver_id);

CREATE INDEX IF NOT EXISTS idx_driver_earnings_trip
  ON driver_earnings(trip_id);

CREATE INDEX IF NOT EXISTS idx_driver_earnings_status
  ON driver_earnings(status);

CREATE TABLE IF NOT EXISTS driver_settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC(20,2) NOT NULL CHECK (amount > 0),
  currency VARCHAR(10) NOT NULL DEFAULT 'IRR',
  status VARCHAR(30) NOT NULL DEFAULT 'pending',
  reference VARCHAR(150),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_driver_settlements_driver
  ON driver_settlements(driver_id);

CREATE INDEX IF NOT EXISTS idx_driver_settlements_status
  ON driver_settlements(status);
