ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS current_latitude NUMERIC(10,7);

ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS current_longitude NUMERIC(10,7);

ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_driver_profiles_online_location
  ON driver_profiles(status, availability_status, current_latitude, current_longitude);
