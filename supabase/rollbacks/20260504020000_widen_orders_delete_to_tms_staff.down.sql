-- Rollback for 20260504020000_widen_orders_delete_to_tms_staff.sql
-- Restores the ADMIN-only DELETE policy from 20260429200000_rls_tier3.sql.

BEGIN;

DROP POLICY IF EXISTS "orders_delete" ON public.orders;

CREATE POLICY "orders_delete" ON public.orders
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND u.role = 'ADMIN'
        AND COALESCE(u.is_active, true) = true
    )
  );

COMMIT;
