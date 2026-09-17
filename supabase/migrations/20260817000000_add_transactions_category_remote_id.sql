-- Applied 2026-08-17 via the Supabase dashboard. See README.md in this folder.
--
-- Transactions referenced categories by the *device-local* Isar id
-- (`category_id bigint`), unlike recurring_transactions which already stores
-- the category's uuid. Local ids differ per device, so a second device maps a
-- pulled transaction onto whichever category happens to hold that integer.
--
-- This adds the uuid reference alongside the legacy column. Nothing is dropped
-- or rewritten:
--   * `category_id` stays not-null and is still written, so a client running
--     the old code keeps working against this schema.
--   * `category_remote_id` is null for every existing row. The app falls back
--     to the legacy column when it is null. Existing rows are deliberately not
--     rewritten in bulk: no single device can know what another device's
--     integer meant. They pick up the uuid when the user next edits them.
--
-- No foreign key: the categories table is not managed by these migrations, so
-- the reference is resolved by the app rather than enforced here.

alter table public.transactions
  add column if not exists category_remote_id uuid;

create index if not exists transactions_user_id_category_remote_id_idx
  on public.transactions (user_id, category_remote_id);
