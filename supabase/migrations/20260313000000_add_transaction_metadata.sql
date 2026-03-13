alter table public.transactions
  add column if not exists payment_method text,
  add column if not exists payee text;
