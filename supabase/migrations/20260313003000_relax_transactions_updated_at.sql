alter table public.transactions
  alter column updated_at drop not null,
  alter column updated_at drop default;

update public.transactions
set updated_at = null
where updated_at is not null
  and created_at is not null
  and abs(extract(epoch from (updated_at - created_at))) < 1;
