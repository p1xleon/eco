alter table public.recurring_transactions
  add column if not exists end_date timestamp without time zone;
