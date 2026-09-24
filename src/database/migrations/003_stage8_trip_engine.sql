BEGIN;

ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS service_type VARCHAR(30) NOT NULL DEFAULT 'ride',
  ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(30),
  ADD COLUMN IF NOT EXISTS estimated_distance_km NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS estimated_duration_min INTEGER,
  ADD COLUMN IF NOT EXISTS estimated_fare NUMERIC(14,0) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS final_fare NUMERIC(14,0),
  ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS passenger_note VARCHAR(1000),
  ADD COLUMN IF NOT EXISTS pricing_version INTEGER NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_trips_service_type
ON trips(service_type);

CREATE INDEX IF NOT EXISTS idx_trips_scheduled_at
ON trips(scheduled_at);

CREATE INDEX IF NOT EXISTS idx_trips_driver_status
ON trips(driver_id,status);

CREATE INDEX IF NOT EXISTS idx_trips_passenger_status
ON trips(passenger_id,status);

COMMIT;
