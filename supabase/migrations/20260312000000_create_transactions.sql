create extension if not exists pgcrypto;

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  amount double precision not null,
  type text not null check (type in ('income', 'expense')),
  category_id bigint not null,
  note text,
  date timestamptz not null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists transactions_user_id_date_idx
  on public.transactions (user_id, date desc);

alter table public.transactions enable row level security;

create policy "Users can read own transactions"
  on public.transactions
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert own transactions"
  on public.transactions
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can delete own transactions"
  on public.transactions
  for delete
  to authenticated
  using (auth.uid() = user_id);
