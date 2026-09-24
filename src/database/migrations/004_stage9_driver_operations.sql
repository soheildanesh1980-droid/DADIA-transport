ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS availability_status VARCHAR(20) NOT NULL DEFAULT 'offline';

ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS last_online_at TIMESTAMPTZ;

ALTER TABLE driver_profiles
  ADD COLUMN IF NOT EXISTS last_offline_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_driver_profiles_availability
  ON driver_profiles(availability_status);

CREATE INDEX IF NOT EXISTS idx_driver_profiles_status_availability
  ON driver_profiles(status, availability_status);
