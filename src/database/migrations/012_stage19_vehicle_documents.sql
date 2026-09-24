CREATE TABLE IF NOT EXISTS vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_type VARCHAR(50) NOT NULL,
  make VARCHAR(100),
  model VARCHAR(100),
  model_year INTEGER CHECK (
    model_year IS NULL OR
    model_year BETWEEN 1900 AND 2200
  ),
  color VARCHAR(50),
  plate_number VARCHAR(100),
  country_code VARCHAR(10),
  status VARCHAR(30) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicles_driver
  ON vehicles(driver_id);

CREATE INDEX IF NOT EXISTS idx_vehicles_status
  ON vehicles(status);

CREATE INDEX IF NOT EXISTS idx_vehicles_country
  ON vehicles(country_code);

CREATE TABLE IF NOT EXISTS driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  document_type VARCHAR(50) NOT NULL,
  document_number VARCHAR(150),
  country_code VARCHAR(10),
  issued_at DATE,
  expires_at DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_documents_driver
  ON driver_documents(driver_id);

CREATE INDEX IF NOT EXISTS idx_driver_documents_status
  ON driver_documents(status);

CREATE INDEX IF NOT EXISTS idx_driver_documents_expiry
  ON driver_documents(expires_at);

CREATE TABLE IF NOT EXISTS vehicle_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  document_type VARCHAR(50) NOT NULL,
  document_number VARCHAR(150),
  country_code VARCHAR(10),
  issued_at DATE,
  expires_at DATE,
  status VARCHAR(30) NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicle_documents_vehicle
  ON vehicle_documents(vehicle_id);

CREATE INDEX IF NOT EXISTS idx_vehicle_documents_status
  ON vehicle_documents(status);

CREATE INDEX IF NOT EXISTS idx_vehicle_documents_expiry
  ON vehicle_documents(expires_at);
