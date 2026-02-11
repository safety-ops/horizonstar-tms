-- Fix Supabase Auth "Database error saving new user"
-- Root cause: custom non-internal trigger(s) on auth.users calling public functions.
-- This project manages app users manually in public.users, so auth.users insert triggers are not required.

DO $$
DECLARE
  trg RECORD;
BEGIN
  FOR trg IN
    SELECT
      t.tgname
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace rel_ns ON rel_ns.oid = c.relnamespace
    JOIN pg_proc p ON p.oid = t.tgfoid
    JOIN pg_namespace fn_ns ON fn_ns.oid = p.pronamespace
    WHERE rel_ns.nspname = 'auth'
      AND c.relname = 'users'
      AND NOT t.tgisinternal
      AND fn_ns.nspname = 'public'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users', trg.tgname);
  END LOOP;
END $$;

-- Remove common legacy helper functions if present.
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.handle_new_users();

