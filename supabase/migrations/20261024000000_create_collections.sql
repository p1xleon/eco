-- Not yet applied. Paste into the Supabase dashboard SQL editor, then note the
-- date here. See README.md in this folder.
--
-- Collections group transactions (a trip, a renovation). A transaction belongs
-- to at most one. `name` holds ciphertext once the user has set up a key; see
-- `lib/features/collections/data/models/collection_mapper.dart`.
--
-- Deleting a collection must never delete transactions, so the reference is
-- `on delete set null`.
--
-- Idempotent.

create extension if not exists pgcrypto;

create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  -- ARGB packed into an int by the app; wider than int4 on purpose.
  color bigint not null,
  icon text,
  -- Its transactions are tracked only in the collection, not the main list.
  separate boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists collections_user_id_idx
  on public.collections (user_id);

alter table public.collections enable row level security;

drop policy if exists "Users can read own collections" on public.collections;
create policy "Users can read own collections"
  on public.collections for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own collections" on public.collections;
create policy "Users can insert own collections"
  on public.collections for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own collections" on public.collections;
create policy "Users can update own collections"
  on public.collections for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own collections" on public.collections;
create policy "Users can delete own collections"
  on public.collections for delete to authenticated
  using (auth.uid() = user_id);

alter table public.transactions
  add column if not exists collection_remote_id uuid
    references public.collections (id) on delete set null;

create index if not exists transactions_user_id_collection_remote_id_idx
  on public.transactions (user_id, collection_remote_id);
