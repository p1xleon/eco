alter table public.transactions
  add column if not exists updated_at timestamptz
  not null
  default timezone('utc', now());
