alter table public.loan_applications add column if not exists submitted_at timestamptz;
alter table public.loan_applications add column if not exists edit_count integer not null default 0;
update public.loan_applications set submitted_at = coalesce(created_at, now()) where submitted_at is null;
alter table public.loan_applications alter column submitted_at set default now();
alter table public.loan_applications alter column submitted_at set not null;

create or replace function private.guard_loan_write()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare
  banker boolean := coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'banker';
begin
  if tg_op = 'DELETE' then
    if old.status <> 'pending' then raise exception 'loan_not_pending'; end if;
    return old;
  end if;
  if tg_op = 'UPDATE' then
    if old.status <> 'pending' then raise exception 'loan_not_pending'; end if;
    if new.id is distinct from old.id or new.user_id is distinct from old.user_id
      or new.created_at is distinct from old.created_at
      or new.submitted_at is distinct from old.submitted_at then
      raise exception 'loan_forbidden';
    end if;
    if banker then
      if new.company_name is distinct from old.company_name
        or new.equipment_name is distinct from old.equipment_name
        or new.amount is distinct from old.amount
        or new.interest_rate is distinct from old.interest_rate
        or new.repayment_years is distinct from old.repayment_years
        or new.edit_count is distinct from old.edit_count then
        raise exception 'loan_forbidden';
      end if;
      return new;
    end if;
    if auth.uid() is distinct from old.user_id or new.status <> 'pending' then
      raise exception 'loan_forbidden';
    end if;
    if old.edit_count >= 2 then raise exception 'loan_edit_limit'; end if;
    new.edit_count := old.edit_count + 1;
  else
    new.edit_count := 0;
    new.submitted_at := now();
  end if;
  if char_length(trim(new.company_name)) not between 1 and 50
    or new.amount not between 5000 and 600000
    or char_length(trim(new.equipment_name)) = 0
    or new.interest_rate not between 0 and 100
    or new.repayment_years not between 1 and 30 then
    raise exception 'loan_invalid_details';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_loan_write() from public, anon, authenticated;
drop trigger if exists loan_write_guard on public.loan_applications;
create trigger loan_write_guard before insert or update or delete on public.loan_applications
for each row execute function private.guard_loan_write();

grant update (company_name, equipment_name, amount, interest_rate, repayment_years)
on public.loan_applications to authenticated;

drop policy if exists loans_update_own_pending on public.loan_applications;
create policy loans_update_own_pending on public.loan_applications for update to authenticated
using ((select auth.uid()) = user_id and status = 'pending')
with check ((select auth.uid()) = user_id and status = 'pending');

drop policy if exists loans_delete_own_pending on public.loan_applications;
create policy loans_delete_own_pending on public.loan_applications for delete to authenticated
using ((select auth.uid()) = user_id and status = 'pending');

create or replace function public.update_pending_loan(
  p_id uuid, p_company_name text, p_equipment_name text, p_amount text,
  p_interest_rate numeric, p_repayment_years integer
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  current_loan public.loan_applications;
begin
  select * into current_loan from public.loan_applications
  where id = p_id and user_id = auth.uid() for update;
  if not found then raise exception 'loan_not_found'; end if;
  if current_loan.status <> 'pending' then raise exception 'loan_not_pending'; end if;
  if current_loan.edit_count >= 2 then raise exception 'loan_edit_limit'; end if;
  if p_amount is null or trim(p_amount) !~ '^[0-9]+\.[0-9]{2}$'
    or p_company_name is null or p_equipment_name is null
    or p_interest_rate is null or p_repayment_years is null then
    raise exception 'loan_invalid_details';
  end if;
  update public.loan_applications set
    company_name = trim(p_company_name), equipment_name = p_equipment_name,
    amount = trim(p_amount)::numeric, interest_rate = p_interest_rate,
    repayment_years = p_repayment_years
  where id = current_loan.id returning * into current_loan;
  return to_jsonb(current_loan);
end;
$$;
revoke all on function public.update_pending_loan(uuid,text,text,text,numeric,integer) from public, anon;
grant execute on function public.update_pending_loan(uuid,text,text,text,numeric,integer) to authenticated;

create or replace function public.delete_pending_loan(p_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  current_loan public.loan_applications;
begin
  select * into current_loan from public.loan_applications
  where id = p_id for update;
  if not found then raise exception 'loan_not_found'; end if;
  if current_loan.status <> 'pending' then raise exception 'loan_not_pending'; end if;
  if current_loan.user_id is distinct from auth.uid()
    and coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') <> 'banker' then
    raise exception 'loan_forbidden';
  end if;
  delete from public.loan_applications where id = current_loan.id;
end;
$$;
revoke all on function public.delete_pending_loan(uuid) from public, anon;
grant execute on function public.delete_pending_loan(uuid) to authenticated;
notify pgrst, 'reload schema';
