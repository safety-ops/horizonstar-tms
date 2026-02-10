-- Driver auth hardening for Driver App email OTP + PIN login
-- Adds driver <-> auth.users link and login field hygiene.

-- 1) Add auth user linkage on drivers.
ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS auth_user_id UUID;

COMMENT ON COLUMN public.drivers.auth_user_id IS
  'Supabase auth.users.id linked to this driver for email OTP login.';

-- Add FK only once.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'drivers_auth_user_id_fkey'
  ) THEN
    ALTER TABLE public.drivers
      ADD CONSTRAINT drivers_auth_user_id_fkey
      FOREIGN KEY (auth_user_id)
      REFERENCES auth.users(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_drivers_auth_user_id
  ON public.drivers(auth_user_id);

-- 2) Normalize existing login data.
UPDATE public.drivers
SET email = LOWER(BTRIM(email))
WHERE email IS NOT NULL
  AND email <> LOWER(BTRIM(email));

UPDATE public.drivers
SET pin_code = BTRIM(pin_code)
WHERE pin_code IS NOT NULL
  AND pin_code <> BTRIM(pin_code);

-- 3) Normalize future inserts/updates automatically.
CREATE OR REPLACE FUNCTION public.normalize_driver_login_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.email IS NOT NULL THEN
    NEW.email := LOWER(BTRIM(NEW.email));
    IF NEW.email = '' THEN
      NEW.email := NULL;
    END IF;
  END IF;

  IF NEW.pin_code IS NOT NULL THEN
    NEW.pin_code := BTRIM(NEW.pin_code);
    IF NEW.pin_code = '' THEN
      NEW.pin_code := NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_normalize_driver_login_fields ON public.drivers;
CREATE TRIGGER trg_normalize_driver_login_fields
BEFORE INSERT OR UPDATE ON public.drivers
FOR EACH ROW
EXECUTE FUNCTION public.normalize_driver_login_fields();

-- 4) Enforce PIN shape for all new writes (without breaking legacy rows).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'drivers_pin_code_six_digits_chk'
  ) THEN
    ALTER TABLE public.drivers
      ADD CONSTRAINT drivers_pin_code_six_digits_chk
      CHECK (pin_code IS NULL OR pin_code ~ '^[0-9]{6}$')
      NOT VALID;
  END IF;
END $$;

-- 5) Add uniqueness for email/PIN when existing data allows it.
DO $$
BEGIN
  IF EXISTS (
    SELECT LOWER(BTRIM(email))
    FROM public.drivers
    WHERE email IS NOT NULL AND BTRIM(email) <> ''
    GROUP BY LOWER(BTRIM(email))
    HAVING COUNT(*) > 1
  ) THEN
    RAISE WARNING 'Skipping email unique index on drivers: duplicate emails exist';
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS idx_drivers_email_unique_lower
      ON public.drivers(LOWER(BTRIM(email)))
      WHERE email IS NOT NULL AND BTRIM(email) <> '';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT pin_code
    FROM public.drivers
    WHERE pin_code IS NOT NULL AND BTRIM(pin_code) <> ''
    GROUP BY pin_code
    HAVING COUNT(*) > 1
  ) THEN
    RAISE WARNING 'Skipping PIN unique index on drivers: duplicate PINs exist';
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS idx_drivers_pin_code_unique
      ON public.drivers(pin_code)
      WHERE pin_code IS NOT NULL AND BTRIM(pin_code) <> '';
  END IF;
END $$;

-- 6) Best-effort backfill of driver.auth_user_id by email match.
UPDATE public.drivers d
SET auth_user_id = au.id
FROM auth.users au
WHERE d.auth_user_id IS NULL
  AND d.email IS NOT NULL
  AND LOWER(BTRIM(d.email)) = LOWER(BTRIM(au.email));
