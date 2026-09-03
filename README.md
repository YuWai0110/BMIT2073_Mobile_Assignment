# BNM SME Automation Financing Platform

A Flutter mobile application created for the TAR UMT BMIT2073 Mobile Application Development assignment. The app simulates an SME equipment financing platform inspired by Bank Negara Malaysia (BNM), with separate experiences for SME employers and bankers.

Repository: [YuWai0110/BMIT2073_Mobile_Assignment](https://github.com/YuWai0110/BMIT2073_Mobile_Assignment)

Implementation snapshot documented on 3 September 2026. The current source code is the final authority if this document and an older handoff note differ.

## Project Purpose

The application helps an SME user:

- Understand historical Malaysian interest-rate trends.
- Create OPR-based equipment purchase alerts.
- Submit and track equipment financing applications.
- Calculate estimated monthly instalments and total repayment.
- Save and manage financing calculation schemes.

A banker role can review the same loan applications and approve or reject them.

## Current Features

### Responsive Layout

- Supports phone and tablet portrait and landscape orientations without locking orientation.
- Login and registration use a two-pane brand-and-form layout in landscape.
- SME loan entry and application history appear side by side in landscape.
- Calculator inputs and calculation results appear side by side in landscape.
- Interest-rate controls and charts adapt to the available width.
- Profile information uses a two-pane layout in landscape.
- The four-tab bottom navigation remains available in every orientation.

### Introduction and Onboarding

- Four-page introduction shown before the login screen.
- Covers the platform, rate monitoring, financing applications, and payment calculations.
- Includes `Skip`, `Next`, page indicators, and `Get Started`.
- Onboarding completion is session-only, so it appears again after restarting the app.

### Authentication and Profile

- Supabase email/password registration and login.
- Password-reset emails through Supabase Auth.
- Persisted Supabase sessions restored at app startup.
- Cloud profile display and editing with owner-only Row Level Security.
- Logout and auth-gated routing.
- Hidden Banker login accessed from the login logo.

### Interest Rate Monitor

- Mock BNM historical data from 1997 to 2026.
- OPR, Base Rate, and Lending Rate cards.
- Custom line chart drawn with Flutter `CustomPainter`.
- Year selection and rate comparison.
- Create, edit, enable, disable, and delete OPR trigger rules.
- In-app notification inbox for triggered rules.

### Loan Approval

- SME users can submit equipment financing applications.
- Applications contain company, equipment, amount, and interest-rate details.
- SME users can view only their own application status.
- Banker users see a review interface instead of the SME submission form.
- Bankers can view all applications, approve or reject pending applications,
  and remove applications.
- Loan applications and status changes persist in Supabase.

### ROI / EMI Calculator

- Calculates equal monthly instalments using the EMI formula.
- Supports equipment price, unit count, loan term, and annual interest rate.
- Displays monthly and total repayment.
- Supports saving, editing, recalculating, and deleting schemes.
- Includes an AI Financing Advisor that uses the current calculation values to return a risk level, recommendation, cash-flow advice, and confidence score.

### SQLite Persistence

- EMI schemes, OPR trigger rules, and trigger notifications are stored locally with SQLite on Android, iOS, and macOS.
- Persisted records load before the application UI starts.
- Saved schemes and rules support insert, update, and delete operations.
- Notifications preserve unread/read state and support individual deletion or clearing the inbox.
- Web builds retain the same manager APIs with an in-memory fallback because standard `sqflite` does not provide browser persistence without an additional web implementation.

## User Roles and Demo Access

### SME Accounts

The Login screen keeps two quick-demo buttons for convenient form filling. The
matching users must first be created in Supabase; they are no longer local mock
accounts.

### Banker Access

The banker entry is hidden on the Login screen:

- Tap the BNM logo seven times within the tap sequence, or long-press it for three seconds.
- Sign in with a Supabase user whose protected `app_metadata.role` is `banker`.
- `AuthManager.isBanker` reads that protected role and determines whether the Loans tab shows the SME or Banker interface.

## Navigation Flow

```text
App Launch
└── OnboardingScreen
    └── Skip / Get Started
        └── Auth Gate
            ├── Not logged in → LoginScreen
            │   ├── Sign Up → SignupScreen
            │   ├── Forgot Password → ForgotPasswordScreen
            │   ├── SME Login
            │   └── Hidden Banker Login
            └── Logged in → Home Shell
                ├── Rates → TriggerScreen
                ├── Loans → LoanScreen
                ├── Calculator → CalcScreen
                └── Profile → ProfileScreen
```

The Home Shell uses a `BottomNavigationBar` and an `IndexedStack`, so tab state is preserved while switching between the four main pages.

## Tech Stack

| Area | Technology |
|---|---|
| Framework | Flutter / Dart |
| Dart SDK | `^3.12.2` |
| UI | Material 3 |
| State management | Provider `^6.1.2` and `ChangeNotifier` |
| Chart | Flutter `CustomPainter` |
| Cloud backend | Supabase Auth and Postgres for profiles and loan applications |
| Local data storage | SQLite for EMI schemes, triggers, and notifications |
| AI advisor | Google Gemini via `google_generative_ai` and `GEMINI_API_KEY` |
| Supported project targets | Android and Web project folders are included |

No Firebase, SharedPreferences, or external chart package is used.

## Project Structure

```text
lib/
├── main.dart
├── core/
│   ├── constants.dart
│   └── mock_data.dart
├── services/
│   ├── database/
│   │   └── database_service.dart
│   └── supabase/
│       ├── supabase_service.dart
│       ├── auth_repository.dart
│       ├── profile_repository.dart
│       └── loan_repository.dart
│   └── ai/
│       ├── gemini_service.dart
│       └── ai_repository.dart
└── features/
    ├── ai/
    │   ├── ai_manager.dart
    │   └── models/ai_recommendation.dart
    ├── onboarding/
    │   └── onboarding_screen.dart
    ├── auth/
    │   ├── auth_manager.dart
    │   ├── login_screen.dart
    │   ├── signup_screen.dart
    │   ├── forgot_password_screen.dart
    │   └── profile_screen.dart
    ├── interest_trigger/
    │   ├── trigger_manager.dart
    │   └── trigger_screen.dart
    ├── loan_approval/
    │   ├── loan_manager.dart
    │   └── loan_screen.dart
    └── calculator_roi/
        ├── calc_manager.dart
        └── calc_screen.dart
```

## Architecture and State

`main.dart` creates four providers with `MultiProvider`:

| Manager | Main responsibility | Important operations |
|---|---|---|
| `AuthManager` | Supabase session, profile, and role | `signUp`, `login`, `bankerLogin`, `logout`, `updateProfile`, `resetPassword` |
| `TriggerManager` | OPR rules and notifications | `addRule`, `editRule`, `toggleRule`, `removeRule`, `checkTriggers`, `clearInbox` |
| `LoanManager` | Loan applications and status | `addLoanRequest`, `updateStatus`, `deleteRequest` |
| `CalcManager` | EMI calculation schemes | `saveScheme`, `updateScheme`, `deleteScheme`, `calculateEMI` |
| `AiManager` | Gemini financing advice | `generateAdvice`, `clearRecommendation` |

`CalcManager` and `TriggerManager` keep their existing Provider APIs while synchronizing changes to SQLite. `AuthManager` and `LoanManager` keep business state in ChangeNotifier while their repositories read and write Supabase. SQLite and Supabase data are loaded before `runApp`.

## Supabase Integration

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the Git-ignored `.env` asset. Only a frontend-safe Publishable or legacy Anon Key belongs there. The complete schema, indexes, grants, triggers, and RLS policies are in `supabase/schema.sql`; setup and migration instructions are in `SUPABASE_SETUP.md`.

## Gemini AI Advisor

The Calculator's AI Financing Advisor reads `GEMINI_API_KEY` from the same Git-ignored `.env` asset. It sends only the current calculator data: equipment name, price, quantity, loan amount, interest rate, repayment years, monthly EMI, and current mock OPR. Gemini is asked to return JSON only, which is validated before the Material 3 recommendation card is shown. Network, timeout, empty-response, and invalid-JSON failures are converted into friendly SnackBars without exposing provider errors.

## SQLite Schema

Database file: `bnm_sme_financing.db`

```sql
CREATE TABLE emi_schemes (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  equipmentPrice REAL NOT NULL,
  quantity INTEGER NOT NULL,
  interestRate REAL NOT NULL,
  loanYears REAL NOT NULL,
  monthlyPayment REAL NOT NULL,
  totalPayment REAL NOT NULL
);

CREATE TABLE trigger_rules (
  id TEXT PRIMARY KEY,
  targetRate REAL NOT NULL,
  comparison TEXT NOT NULL,
  enabled INTEGER NOT NULL,
  createdAt TEXT NOT NULL,
  equipmentType TEXT NOT NULL
);

CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  message TEXT NOT NULL UNIQUE,
  timestamp TEXT NOT NULL,
  isRead INTEGER NOT NULL
);
```

The first database version creates all three tables. No migration is needed for existing installations because the previous app did not create a database. Future schema changes must increment `DatabaseService.databaseVersion` and add an `onUpgrade` migration before release.

## Run the Project

Requirements:

- Flutter SDK compatible with Dart `^3.12.2`.
- Android Studio with an emulator, an Android device, or a supported web browser.

From the project root:

```bash
flutter pub get
flutter analyze
flutter run
```

To run specifically in Chrome with the in-memory database fallback:

```bash
flutter run -d chrome
```

## Assignment Constraints

Anyone modifying this project, including an AI assistant, must preserve these constraints unless the project owner explicitly changes them:

1. Do not add `//`, `///`, or block comments to Dart source files. The assignment requires comment-free `.dart` files.
2. Keep the interest-rate chart implemented with Flutter `CustomPainter`; do not replace it with an external chart package.
3. Keep calculator schemes, trigger rules, and trigger notifications in SQLite. Do not move these modules to a remote backend.
4. Preserve the two roles and the role-specific Loans tab.
5. Preserve the four-tab `BottomNavigationBar` and `IndexedStack` navigation unless a navigation redesign is requested.
6. Avoid editing unrelated files when working on an isolated feature.

## Known Limitations

- Data is demonstration data and is not fetched live from BNM.
- Onboarding is shown on every fresh app launch because its completion is not persisted.
- The two quick-demo credentials work only after matching Supabase users are created.
- Password-reset email redirects must be configured in the Supabase Auth URL settings for the selected test environment.

## Guidance for AI Assistants

Before changing the project:

1. Read this README first. Treat `CODEX_HANDOFF.md` as supplementary context because it may be older than the current source.
2. Inspect `git status` and preserve unrelated local changes.
3. Inspect the relevant screen and its manager before editing.
4. Use existing `AppColors`, `AppTheme`, and `appInputDecoration` for consistent UI.
5. Keep business logic in the relevant `ChangeNotifier` manager where practical.
6. Do not add Dart comments.
7. Format changed Dart files and run `flutter analyze` after implementation.
8. Report any check that could not be completed instead of claiming it passed.

## Collaboration Workflow

Use one branch per contribution:

```bash
git switch -c feature/short-feature-name
git add path/to/changed/files
git commit -m "feat: describe the contribution"
git push -u origin feature/short-feature-name
```

Open a Pull Request into `main`, review the changed files, test the feature, and merge only after confirmation. Each contributor should commit and push their own genuine work using their own GitHub account.
