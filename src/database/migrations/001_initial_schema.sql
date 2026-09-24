CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='user_role') THEN
    CREATE TYPE user_role AS ENUM ('passenger','driver','admin');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='user_status') THEN
    CREATE TYPE user_status AS ENUM ('active','inactive','blocked');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='driver_status') THEN
    CREATE TYPE driver_status AS ENUM ('pending','approved','rejected','suspended');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='trip_status') THEN
    CREATE TYPE trip_status AS ENUM (
      'requested','searching','accepted','arriving',
      'started','completed','cancelled'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='cargo_status') THEN
    CREATE TYPE cargo_status AS ENUM (
      'created','searching','accepted','picked_up',
      'in_transit','delivered','cancelled'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='payment_status') THEN
    CREATE TYPE payment_status AS ENUM (
      'pending','paid','failed','refunded'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(20) NOT NULL UNIQUE,
  full_name VARCHAR(150),
  role user_role NOT NULL DEFAULT 'passenger',
  status user_status NOT NULL DEFAULT 'active',
  password_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS passenger_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  national_id VARCHAR(20),
  rating NUMERIC(3,2) DEFAULT 5.00,
  total_trips INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS driver_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  national_id VARCHAR(20),
  license_number VARCHAR(50),
  status driver_status NOT NULL DEFAULT 'pending',
  rating NUMERIC(3,2) DEFAULT 5.00,
  total_trips INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES driver_profiles(user_id) ON DELETE CASCADE,
  vehicle_type VARCHAR(50) NOT NULL,
  brand VARCHAR(80),
  model VARCHAR(80),
  plate_number VARCHAR(30) UNIQUE,
  color VARCHAR(40),
  year INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(100),
  address TEXT NOT NULL,
  latitude NUMERIC(10,7),
  longitude NUMERIC(10,7),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  passenger_id UUID NOT NULL REFERENCES passenger_profiles(user_id),
  driver_id UUID REFERENCES driver_profiles(user_id),
  vehicle_id UUID REFERENCES vehicles(id),
  status trip_status NOT NULL DEFAULT 'requested',

  origin_address TEXT NOT NULL,
  origin_latitude NUMERIC(10,7) NOT NULL,
  origin_longitude NUMERIC(10,7) NOT NULL,

  destination_address TEXT NOT NULL,
  destination_latitude NUMERIC(10,7) NOT NULL,
  destination_longitude NUMERIC(10,7) NOT NULL,

  estimated_distance_km NUMERIC(10,2),
  estimated_duration_min INTEGER,
  estimated_fare BIGINT,
  final_fare BIGINT,

  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cargo_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES users(id),
  driver_id UUID REFERENCES driver_profiles(user_id),
  vehicle_id UUID REFERENCES vehicles(id),
  status cargo_status NOT NULL DEFAULT 'created',

  origin_address TEXT NOT NULL,
  origin_latitude NUMERIC(10,7) NOT NULL,
  origin_longitude NUMERIC(10,7) NOT NULL,

  destination_address TEXT NOT NULL,
  destination_latitude NUMERIC(10,7) NOT NULL,
  destination_longitude NUMERIC(10,7) NOT NULL,

  cargo_type VARCHAR(100),
  weight_kg NUMERIC(12,2),
  volume_m3 NUMERIC(12,3),
  description TEXT,

  estimated_price BIGINT,
  final_price BIGINT,

  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  picked_up_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
  cargo_order_id UUID REFERENCES cargo_orders(id) ON DELETE SET NULL,
  amount BIGINT NOT NULL,
  status payment_status NOT NULL DEFAULT 'pending',
  gateway VARCHAR(80),
  gateway_transaction_id VARCHAR(150),
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trip_locations (
  id BIGSERIAL PRIMARY KEY,
  trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES driver_profiles(user_id),
  latitude NUMERIC(10,7) NOT NULL,
  longitude NUMERIC(10,7) NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_driver_status ON driver_profiles(status);
CREATE INDEX IF NOT EXISTS idx_vehicles_driver ON vehicles(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_passenger ON trips(passenger_id);
CREATE INDEX IF NOT EXISTS idx_trips_driver ON trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status);
CREATE INDEX IF NOT EXISTS idx_cargo_customer ON cargo_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_cargo_driver ON cargo_orders(driver_id);
CREATE INDEX IF NOT EXISTS idx_cargo_status ON cargo_orders(status);
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_trip_locations_trip ON trip_locations(trip_id);
