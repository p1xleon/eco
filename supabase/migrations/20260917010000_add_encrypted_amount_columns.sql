-- Makes room for end-to-end encrypted amounts.
--
-- Text fields (`title`, `note`, `payee`, `payment_method`, `categories.name`)
-- already hold text, so ciphertext goes straight into them and needs no schema
-- change. Amounts are `double precision` and cannot, so they get their own text
-- columns.
--
-- Nothing is dropped or rewritten. `amount` loses only its NOT NULL, because an
-- encrypted row leaves it empty; a client running the old code still reads and
-- writes it, and rows written before the migration keep their numeric value.
-- The app reads whichever of the two is present.
--
-- Apply through the dashboard SQL editor, per README.md.

alter table public.transactions
  add column if not exists amount_enc text;

alter table public.transactions
  alter column amount drop not null;

alter table public.recurring_transactions
  add column if not exists default_amount_enc text;
