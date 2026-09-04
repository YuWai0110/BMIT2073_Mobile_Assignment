# Auth user deletion cascade fix

Applied to BMIT2073_OptiMach (wtwfvfllwxbzxbwerqov).

Migration: `20260904060501_allow_auth_user_delete_cascade.sql`.

All 10 foreign keys referencing auth.users already use ON DELETE CASCADE,
including profiles_id_fkey and loan_applications_user_id_fkey. No foreign key
needed replacement. The loan_write_guard trigger raised loan_not_pending for
approved/rejected loans during Auth user deletion. This was reproduced inside
a rolled-back transaction before applying the fix.

The migration changes only private.guard_loan_write(). It permits deletion when
the trigger is nested, the database role is postgres or supabase_auth_admin,
and the parent Auth user no longer exists. Ordinary loan updates/deletes retain
the existing pending-only checks. RLS policies and grants remain unchanged.
No Flutter code, Auth settings, or existing user data is changed by this migration.

Run `tests/auth_user_delete_cascade.sql` in the SQL editor. It lists all related
foreign keys and orphan counts, creates a temporary test user and three loan
statuses inside a transaction, confirms direct approved-loan deletion is blocked,
checks the Auth deletion cascade, and rolls back all test writes.

Live SQL test result: PASS. Before/after: 8 Auth users, 8 profiles, 7 loans.
Orphan profiles: 0. Orphan loans: 0.

Verification used the postgres database role. The MCP connection cannot SET ROLE
supabase_auth_admin, so the actual Authentication > Users deletion button remains
a manual confirmation. Do not delete a real user merely to test this: successful
deletion now removes their related records permanently.

No new database security-advisor findings. The existing Leaked Password Protection
Disabled warning is unrelated and its project setting was left unchanged.
