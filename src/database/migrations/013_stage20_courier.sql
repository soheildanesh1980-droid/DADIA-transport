CREATE TABLE IF NOT EXISTS courier_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  passenger_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES users(id) ON DELETE SET NULL,

  origin_address TEXT NOT NULL,
  destination_address TEXT NOT NULL,

  origin_lat DOUBLE PRECISION NOT NULL,
  origin_lng DOUBLE PRECISION NOT NULL,
  destination_lat DOUBLE PRECISION NOT NULL,
  destination_lng DOUBLE PRECISION NOT NULL,

  package_description TEXT,
  package_weight_kg NUMERIC(12,3),

  recipient_name TEXT,
  recipient_phone TEXT,
  passenger_phone TEXT,

  country_code VARCHAR(10) NOT NULL DEFAULT 'IR',
  currency VARCHAR(10) NOT NULL DEFAULT 'IRR',

  status VARCHAR(30) NOT NULL DEFAULT 'requested',

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_courier_orders_passenger
  ON courier_orders(passenger_id);

CREATE INDEX IF NOT EXISTS idx_courier_orders_driver
  ON courier_orders(driver_id);

CREATE INDEX IF NOT EXISTS idx_courier_orders_status
  ON courier_orders(status);

CREATE INDEX IF NOT EXISTS idx_courier_orders_country
  ON courier_orders(country_code);

CREATE INDEX IF NOT EXISTS idx_courier_orders_created
  ON courier_orders(created_at DESC);
