-- Reconstructs `categories`, which was created through the dashboard and never
-- written down here. See README.md: the original definition was lost when the
-- project was deleted on 2026-09-17, so this is rebuilt from the app's mapper
-- (`lib/features/categories/data/models/category_mapper.dart`) rather than from
-- a dump of the live table.
--
-- Idempotent, and a no-op against a database that already has the table.

create extension if not exists pgcrypto;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  type text not null check (type in ('income', 'expense')),
  -- ARGB packed into an int by the app; wider than int4 on purpose.
  color bigint not null,
  icon text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists categories_user_id_name_idx
  on public.categories (user_id, name);

alter table public.categories enable row level security;

-- `create policy` has no `if not exists`, so drop first to stay re-runnable.
drop policy if exists "Users can read own categories" on public.categories;
create policy "Users can read own categories"
  on public.categories
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own categories" on public.categories;
create policy "Users can insert own categories"
  on public.categories
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own categories" on public.categories;
create policy "Users can update own categories"
  on public.categories
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own categories" on public.categories;
create policy "Users can delete own categories"
  on public.categories
  for delete
  to authenticated
  using (auth.uid() = user_id);
