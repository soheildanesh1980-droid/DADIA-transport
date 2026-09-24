CREATE TABLE IF NOT EXISTS heavy_truck_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  passenger_id UUID NOT NULL
    REFERENCES users(id) ON DELETE CASCADE,

  driver_id UUID
    REFERENCES users(id) ON DELETE SET NULL,

  origin_address TEXT NOT NULL,
  destination_address TEXT NOT NULL,

  origin_lat DOUBLE PRECISION NOT NULL,
  origin_lng DOUBLE PRECISION NOT NULL,

  destination_lat DOUBLE PRECISION NOT NULL,
  destination_lng DOUBLE PRECISION NOT NULL,

  cargo_type VARCHAR(100),
  cargo_description TEXT,

  weight_ton NUMERIC(12,3),
  volume_m3 NUMERIC(12,3),

  vehicle_type VARCHAR(100),
  truck_type VARCHAR(100),

  axle_count INTEGER,

  requires_trailer BOOLEAN NOT NULL DEFAULT FALSE,
  trailer_type VARCHAR(100),

  loading_type VARCHAR(100),
  special_requirements TEXT,

  recipient_name TEXT,
  recipient_phone TEXT,
  passenger_phone TEXT,

  country_code VARCHAR(10) NOT NULL DEFAULT 'IR',
  currency VARCHAR(10) NOT NULL DEFAULT 'IRR',

  status VARCHAR(30) NOT NULL DEFAULT 'requested',

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT heavy_truck_weight_valid
    CHECK (weight_ton IS NULL OR weight_ton > 0),

  CONSTRAINT heavy_truck_volume_valid
    CHECK (volume_m3 IS NULL OR volume_m3 > 0),

  CONSTRAINT heavy_truck_axle_valid
    CHECK (axle_count IS NULL OR axle_count > 0)
);

CREATE INDEX IF NOT EXISTS idx_heavy_truck_passenger
  ON heavy_truck_orders(passenger_id);

CREATE INDEX IF NOT EXISTS idx_heavy_truck_driver
  ON heavy_truck_orders(driver_id);

CREATE INDEX IF NOT EXISTS idx_heavy_truck_status
  ON heavy_truck_orders(status);

CREATE INDEX IF NOT EXISTS idx_heavy_truck_country
  ON heavy_truck_orders(country_code);

CREATE INDEX IF NOT EXISTS idx_heavy_truck_created
  ON heavy_truck_orders(created_at DESC);
