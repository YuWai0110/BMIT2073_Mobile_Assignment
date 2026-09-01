# Supabase Setup

This project uses the existing `BMIT2073_OptiMach` Supabase project. Do not create a second project.

## 1. Configure the Flutter environment

Copy `.env.example` to `.env` and fill in the existing project's values:

```text
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-publishable-or-anon-key
```

Use the Publishable Key when the dashboard provides one. A legacy Anon Key also works. Never place a Secret Key or Service Role Key in the Flutter project. The `.env` file is ignored by Git but is bundled as a Flutter asset during a local build, so only frontend-safe publishable credentials belong there.

## 2. Create the database objects

Open the existing Supabase project, select **SQL Editor**, paste the full contents of `supabase/schema.sql`, and run it once. The script creates:

- `public.profiles`
- `public.loan_applications`
- Profile creation and update triggers
- Foreign keys, checks, and indexes
- Explicit Data API privileges
- Row Level Security policies for SME and Banker access

Run the script before testing registration because the Auth trigger creates a matching profile row for each new user.

## 3. Configure authentication

In **Authentication → Providers → Email**, keep Email/Password enabled. Choose whether email confirmation is required. When confirmation is enabled, a new user must confirm the email before logging in.

In **Authentication → URL Configuration**, set the Site URL and allowed redirect URLs for the environment used to test password reset emails.

Create SME accounts through the app's Sign Up screen. The two quick-demo buttons only fill the form; the matching Supabase users must exist before those credentials can log in.

## 4. Create a Banker account

Create the Banker user in **Authentication → Users** or sign it up normally. Then replace the email in this SQL and run it in **SQL Editor**:

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object('role', 'banker')
where lower(email) = lower('banker@example.com');
```

The Banker must sign out and sign in again after this update so the refreshed JWT contains `app_metadata.role = banker`. Never put the Banker role in user metadata because users can edit that metadata themselves.

## 5. Run the app

```bash
flutter pub get
flutter run
```

Supabase restores an existing session when the app starts. SQLite continues to store EMI schemes, trigger rules, and the notification inbox locally.

## Migration Notes

- Existing mock users are not copied automatically. Create real users in Supabase.
- Existing in-memory loan applications are not migrated because they were not persisted.
- SQLite tables and data are unchanged.
- The hidden Banker entry now requires a real Supabase Banker email and password. The old local `BNM2026` bypass is intentionally removed.
- Onboarding remains session-only and is unrelated to Supabase session persistence.

## Testing Checklist

- Register a new SME and confirm a `profiles` row is created.
- Confirm email if the project requires email confirmation.
- Log in, restart the app, and verify the session is restored.
- Edit the SME profile and verify the row changes in Supabase.
- Request a password reset and verify the email arrives.
- Submit an SME loan and verify it appears after restarting the app.
- Log in as a second SME and verify the first SME's loans are hidden.
- Log in as a Banker and verify all loans are visible.
- Approve and reject pending loans and verify the status persists.
- Verify an SME cannot update loan status through the Data API.
- Verify an SME cannot read or edit another profile.
- Confirm EMI schemes, trigger rules, and notification inbox still use SQLite.
- Test portrait and landscape layouts after Supabase data loads.
