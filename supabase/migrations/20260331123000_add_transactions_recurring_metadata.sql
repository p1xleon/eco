alter table public.transactions
  add column if not exists recurring_id text,
  add column if not exists recurring_template_id bigint,
  add column if not exists is_recurring_instance boolean;

create index if not exists transactions_user_id_recurring_template_id_idx
  on public.transactions (user_id, recurring_template_id);
