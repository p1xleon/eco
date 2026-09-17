# Migrations

Schema changes on this project are applied **by hand, through the Supabase
dashboard's SQL editor**. The files here are a written record of what was run —
not a history the CLI has applied.

## Do not run `supabase db push`

The remote migration history is empty, so the CLI would try to replay this
entire folder against a database that already has everything. Two files make
that actively unsafe:

- `20260313003000_relax_transactions_updated_at.sql` is not a schema change. It
  contains an `update ... set updated_at = null`, which would rewrite real rows.
- `20260313001000_add_transactions_update_policy.sql` uses a bare
  `create policy`. Postgres has no `if not exists` for policies, so it would
  fail as a duplicate.

For the same reason, never run `supabase db reset` — it drops and rebuilds the
database.

## Adding a change

1. Write the SQL in a new file here, named `<utc-timestamp>_<description>.sql`.
2. Make it idempotent (`if not exists`, `add column`, and so on) so re-running
   it is harmless.
3. Paste it into the dashboard SQL editor and run it.
4. Note the date it was applied in the file's header comment.

## This folder now describes the whole database

It did not until 2026-09-17, and that cost a rebuild. `categories`,
`recurring_transactions` and `transactions.status` were dashboard changes that
were never written down, so when the project was deleted there was nothing to
replay. They were reconstructed from the app's mappers — not from a dump of the
live tables, which no longer existed:

- `20260917000000_create_categories.sql`
- `20260917000100_create_recurring_transactions.sql`
- `20260917000200_add_transactions_status.sql`

The lesson holds generally: a change applied only in the dashboard exists
nowhere else. Write the file first, then run it.

## Order matters when rebuilding from scratch

Filename order is *not* runnable order on an empty database.
`20260331130000_add_recurring_transactions_end_date.sql` sorts before the file
that creates the table it alters, and `recurring_transactions` references
`categories`. For a new environment, run:

1. `20260312000000_create_transactions.sql`
2. `20260917000000_create_categories.sql`
3. `20260917000100_create_recurring_transactions.sql`
4. every remaining `alter`, oldest first

Each file is idempotent, so the out-of-order `alter` is a no-op when it comes
round.
