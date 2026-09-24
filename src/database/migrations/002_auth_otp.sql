DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'auth_otps'
  ) THEN

    CREATE TABLE public.auth_otps (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      phone VARCHAR(20) NOT NULL,
      purpose VARCHAR(30) NOT NULL DEFAULT 'registration',
      code_hash TEXT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      max_attempts INTEGER NOT NULL DEFAULT 5,
      consumed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_auth_otps_phone_purpose
  ON public.auth_otps (phone, purpose);

CREATE INDEX IF NOT EXISTS idx_auth_otps_expires_at
  ON public.auth_otps (expires_at);
