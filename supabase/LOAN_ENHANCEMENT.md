# Loan enhancement

Supabase remains the source of truth. SQLite is unchanged; no loan cache is introduced.

## Applied migrations

- `20260904042545_loan_approval_enhancement.sql`
- `20260904043208_remove_loan_edit_limit.sql`

Both migrations were applied to BMIT2073_OptiMach. The second migration supersedes the originally requested edit limit. Final schema contains `submitted_at`, but no `edit_count`. Pending loans can be edited without a numerical limit. Keep both migration files in order to reproduce the applied history; `schema.sql` contains the final, unlimited-edit schema for fresh setup.

Existing submitted dates are populated from `created_at`, with `now()` as fallback. New submission dates are server-generated timestamps and displayed in device-local time. Existing loan records are preserved, including older amounts outside the new range. New inserts and SME edits must meet the new rules. Banker status decisions do not invalidate legacy amounts.

## Security

`update_pending_loan` and `delete_pending_loan` run as SECURITY INVOKER, fetch the latest record under a row lock, and preserve RLS. Owners can update/delete only their pending applications. Banker authorization continues to use protected `app_metadata.role`. The write trigger prevents direct API calls from bypassing status, ownership, or immutable-field protection. No credential or environment changes are required.

Updates and deletes refresh the visible cloud list after success. Validation and drafts remain in LoanManager. A failed update keeps the draft and displays a friendly message.

## Verification

Run `flutter analyze` and `flutter test` locally. `tests/loan_approval_rules.sql` exercises database rules with an existing SME actor in a transaction and rolls back its test rows. It tests five successful edits, unchanged dates, invalid amounts/company, cross-user isolation, pending deletion and approved-record protection. This is an administrative test script, not application code.

The security advisor reported only the existing disabled leaked-password-protection warning; Auth configuration was left unchanged.
