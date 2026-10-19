# eco

A Flutter personal-finance app for tracking income and expenses. Data is stored locally (Isar) and synced to Supabase.

## Features

- Transactions: add, edit, filter, group by month or custom group, and import from a file with field mapping
- Categories and transaction presets (defaults are seeded on first launch)
- Recurring transactions
- Dashboard and analytics charts
- Privacy option to hide transaction amounts
- Light/dark theme with dynamic color
- Email sign-up and login via Supabase

## Stack

Flutter, Riverpod, go_router, Isar (`isar_community`), Supabase, fl_chart. Code is organized by feature under `lib/features`, with shared code in `lib/core` and `lib/shared`.

## Setup

1. Install Flutter (Dart SDK `^3.11.0`) and run `flutter pub get`.
2. Create a `.env` file in the project root (the app throws at startup if either value is missing):
   ```
   SUPABASE_URL=...
   SUPABASE_ANON_KEY=...
   ```
3. Apply the SQL in `supabase/migrations` to your Supabase project.
4. Generate Isar/JSON code if the `*.g.dart` files are out of date:
   ```
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Run the app with `flutter run`.

## Tests

```
flutter test
```
