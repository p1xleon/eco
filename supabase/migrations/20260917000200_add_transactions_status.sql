-- Adds `transactions.status`, applied through the dashboard and never written
-- down here. See README.md, which flagged this gap before the project was lost.
--
-- The app writes `status.name` on every push and reads anything that is not
-- 'pending' as 'paid' (`transaction_mapper.dart`), so the default matches the
-- reader's fallback.

alter table public.transactions
  add column if not exists status text not null default 'paid';

do $$
begin
  alter table public.transactions
    add constraint transactions_status_check
    check (status in ('paid', 'pending'));
exception
  when duplicate_object then null;
end
$$;
