-- Housekeeping: remove the verification rows inserted while testing the
-- driver_applications RLS rollout in 20260429120000. These were submitted
-- via curl with `first_name IN ('VERIFY_TEST', 'FINAL_VERIFY')` and
-- `last_name = 'DELETEME'`. No real applicants used these names; the
-- predicate is narrow enough to be safe.
DELETE FROM driver_applications
WHERE first_name IN ('VERIFY_TEST', 'FINAL_VERIFY')
  AND last_name = 'DELETEME';
