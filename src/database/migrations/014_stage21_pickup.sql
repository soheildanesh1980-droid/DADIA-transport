CREATE TABLE IF NOT EXISTS pickup_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  passenger_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES users(id) ON DELETE SET NULL,

  origin_address TEXT NOT NULL,
  destination_address TEXT NOT NULL,

  origin_lat DOUBLE PRECISION NOT NULL,
  origin_lng DOUBLE PRECISION NOT NULL,
  destination_lat DOUBLE PRECISION NOT NULL,
  destination_lng DOUBLE PRECISION NOT NULL,

  cargo_type VARCHAR(100),
  cargo_description TEXT,

  weight_kg NUMERIC(12,3),
  volume_m3 NUMERIC(12,3),

  vehicle_type VARCHAR(100),

  recipient_name TEXT,
  recipient_phone TEXT,
  passenger_phone TEXT,

  country_code VARCHAR(10) NOT NULL DEFAULT 'IR',
  currency VARCHAR(10) NOT NULL DEFAULT 'IRR',

  status VARCHAR(30) NOT NULL DEFAULT 'requested',

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pickup_orders_passenger
  ON pickup_orders(passenger_id);

CREATE INDEX IF NOT EXISTS idx_pickup_orders_driver
  ON pickup_orders(driver_id);

CREATE INDEX IF NOT EXISTS idx_pickup_orders_status
  ON pickup_orders(status);

CREATE INDEX IF NOT EXISTS idx_pickup_orders_country
  ON pickup_orders(country_code);

CREATE INDEX IF NOT EXISTS idx_pickup_orders_created
  ON pickup_orders(created_at DESC);
