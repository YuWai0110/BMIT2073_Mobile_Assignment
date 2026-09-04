-- All existing auth.users foreign keys already use ON DELETE CASCADE.
-- Preserve them and fix the application trigger blocking the cascade.
create or replace function private.guard_loan_write()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare
  banker boolean := coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'banker';
begin
  if tg_op = 'DELETE' then
    if pg_trigger_depth() > 1 and current_user in ('postgres', 'supabase_auth_admin') then
      if not exists (select 1 from auth.users where id = old.user_id) then
        return old;
      end if;
    end if;
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
        or new.repayment_years is distinct from old.repayment_years then
        raise exception 'loan_forbidden';
      end if;
      return new;
    end if;
    if auth.uid() is distinct from old.user_id or new.status <> 'pending' then
      raise exception 'loan_forbidden';
    end if;
  else
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
