CREATE TABLE IF NOT EXISTS moving_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  passenger_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES users(id) ON DELETE SET NULL,

  origin_address TEXT NOT NULL,
  destination_address TEXT NOT NULL,

  origin_lat DOUBLE PRECISION NOT NULL,
  origin_lng DOUBLE PRECISION NOT NULL,
  destination_lat DOUBLE PRECISION NOT NULL,
  destination_lng DOUBLE PRECISION NOT NULL,

  move_type VARCHAR(100),
  description TEXT,

  estimated_weight_kg NUMERIC(12,3),
  estimated_volume_m3 NUMERIC(12,3),

  vehicle_type VARCHAR(100),
  helper_count INTEGER,

  moving_date DATE,
  moving_time TIME,

  recipient_name TEXT,
  recipient_phone TEXT,
  passenger_phone TEXT,

  country_code VARCHAR(10) NOT NULL DEFAULT 'IR',
  currency VARCHAR(10) NOT NULL DEFAULT 'IRR',

  status VARCHAR(30) NOT NULL DEFAULT 'requested',

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT moving_helper_count_valid
    CHECK (helper_count IS NULL OR helper_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_moving_orders_passenger
  ON moving_orders(passenger_id);

CREATE INDEX IF NOT EXISTS idx_moving_orders_driver
  ON moving_orders(driver_id);

CREATE INDEX IF NOT EXISTS idx_moving_orders_status
  ON moving_orders(status);

CREATE INDEX IF NOT EXISTS idx_moving_orders_country
  ON moving_orders(country_code);

CREATE INDEX IF NOT EXISTS idx_moving_orders_created
  ON moving_orders(created_at DESC);
