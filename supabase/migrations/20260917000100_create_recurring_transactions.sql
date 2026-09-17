-- Reconstructs `recurring_transactions`, created through the dashboard and
-- never written down here. See README.md and the sibling
-- `20260917000000_create_categories.sql`.
--
-- Rebuilt from `lib/features/recurring/data/models/recurring_transaction_mapper.dart`.
-- Two details worth knowing, both taken from the app rather than invented here:
--
--   * `category_id` is a uuid referencing `categories`, unlike
--     `transactions.category_id`, which is the device-local Isar integer. The
--     mapper sends the category's remote id for this table.
--   * `end_date` is `timestamp without time zone`, matching what
--     `20260331130000_add_recurring_transactions_end_date.sql` added. That file
--     runs before this one by filename order, so the column is included here to
--     keep a fresh rebuild working; the older file is then a no-op.

create extension if not exists pgcrypto;

create table if not exists public.recurring_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  type text not null check (type in ('income', 'expense')),
  default_amount double precision,
  amount_type text not null default 'fixed'
    check (amount_type in ('fixed', 'variable')),
  category_id uuid references public.categories (id) on delete set null,
  account_id text,
  interval_type text not null default 'monthly'
    check (interval_type in ('daily', 'weekly', 'monthly', 'yearly')),
  interval_count integer not null default 1,
  next_due_date timestamptz not null,
  end_date timestamp without time zone,
  is_active boolean not null default true,
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz
);

create index if not exists recurring_transactions_user_id_next_due_date_idx
  on public.recurring_transactions (user_id, next_due_date);

alter table public.recurring_transactions enable row level security;

drop policy if exists "Users can read own recurring transactions"
  on public.recurring_transactions;
create policy "Users can read own recurring transactions"
  on public.recurring_transactions
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own recurring transactions"
  on public.recurring_transactions;
create policy "Users can insert own recurring transactions"
  on public.recurring_transactions
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own recurring transactions"
  on public.recurring_transactions;
create policy "Users can update own recurring transactions"
  on public.recurring_transactions
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own recurring transactions"
  on public.recurring_transactions;
create policy "Users can delete own recurring transactions"
  on public.recurring_transactions
  for delete
  to authenticated
  using (auth.uid() = user_id);
