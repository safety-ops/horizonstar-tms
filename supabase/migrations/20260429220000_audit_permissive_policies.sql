-- Follow-up audit: list any RLS policy with predicate = "true" on a public
-- table (effectively permissive, same as no RLS). Plus list ALL policies on
-- chat_messages and tasks specifically since those are realtime-subscribed.

DO $$
DECLARE
  rec RECORD;
BEGIN
  RAISE NOTICE '--- POLICIES WITH USING (true) OR WITH CHECK (true) ---';
  FOR rec IN
    SELECT schemaname, tablename, policyname, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (qual = 'true' OR with_check = 'true')
    ORDER BY tablename, policyname
  LOOP
    RAISE NOTICE 'PERMISSIVE: %.% policy="%" cmd=% qual=% with_check=%',
      rec.schemaname, rec.tablename, rec.policyname, rec.cmd,
      COALESCE(rec.qual, 'NULL'), COALESCE(rec.with_check, 'NULL');
  END LOOP;

  RAISE NOTICE '--- ALL POLICIES ON chat_messages, tasks, messages ---';
  FOR rec IN
    SELECT schemaname, tablename, policyname, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('chat_messages', 'tasks', 'messages')
    ORDER BY tablename, policyname
  LOOP
    RAISE NOTICE 'POLICY: %.% name="%" cmd=% qual=% with_check=%',
      rec.schemaname, rec.tablename, rec.policyname, rec.cmd,
      COALESCE(rec.qual, 'NULL'), COALESCE(rec.with_check, 'NULL');
  END LOOP;
END$$;
