-- One-shot discovery: list every public.* table that does NOT have RLS
-- enabled, plus tables that have RLS enabled but ZERO policies (also
-- effectively unprotected for non-service-role callers).
--
-- NOTICE-only — no schema changes. Used by the P0 closing gate to find
-- Studio-created tables we missed during the migration sweep.

DO $$
DECLARE
  rec RECORD;
  unprotected_count INTEGER := 0;
  no_policy_count INTEGER := 0;
BEGIN
  FOR rec IN
    SELECT c.relname, c.relrowsecurity
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'  -- ordinary tables only
    ORDER BY c.relname
  LOOP
    IF NOT rec.relrowsecurity THEN
      RAISE NOTICE 'AUDIT-NO-RLS: public.%', rec.relname;
      unprotected_count := unprotected_count + 1;
    ELSE
      DECLARE
        policy_count INTEGER;
      BEGIN
        SELECT COUNT(*) INTO policy_count
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = rec.relname;
        IF policy_count = 0 THEN
          RAISE NOTICE 'AUDIT-RLS-NO-POLICY: public.% (RLS enabled but 0 policies — denies all)', rec.relname;
          no_policy_count := no_policy_count + 1;
        END IF;
      END;
    END IF;
  END LOOP;
  RAISE NOTICE 'AUDIT-SUMMARY: % tables with NO RLS, % tables RLS-on with ZERO policies', unprotected_count, no_policy_count;
END$$;
