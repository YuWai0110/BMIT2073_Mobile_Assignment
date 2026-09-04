create schema if not exists private;

revoke all on schema private from public, anon, authenticated;

do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'rls_auto_enable'
      and pg_get_function_identity_arguments(p.oid) = ''
  ) then
    execute 'revoke all on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null check (char_length(trim(full_name)) > 0),
  company_name text not null default '',
  phone text not null default '',
  email text not null check (char_length(trim(email)) > 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.loan_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  company_name text not null check (char_length(trim(company_name)) > 0),
  equipment_name text not null check (char_length(trim(equipment_name)) > 0),
  amount numeric(14, 2) not null check (amount > 0),
  interest_rate numeric(6, 3) not null check (
    interest_rate >= 0 and interest_rate <= 100
  ),
  repayment_years integer not null default 5 check (repayment_years > 0),
  status text not null default 'pending' check (
    status in ('pending', 'approved', 'rejected')
  ),
  created_at timestamptz not null default now()
);

create index if not exists loan_applications_user_id_idx
  on public.loan_applications (user_id);

create index if not exists loan_applications_status_created_at_idx
  on public.loan_applications (status, created_at desc);

create or replace function private.set_profile_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_profile_updated_at();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id,
    full_name,
    company_name,
    phone,
    email
  )
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'SME User'),
    coalesce(new.raw_user_meta_data ->> 'company_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.email, '')
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    company_name = excluded.company_name,
    phone = excluded.phone,
    email = excluded.email;
  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;
revoke all on function private.set_profile_updated_at() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

alter table public.profiles enable row level security;
alter table public.loan_applications enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.loan_applications from anon, authenticated;

grant usage on schema public to authenticated;
grant select on table public.profiles to authenticated;
grant insert (id, full_name, company_name, phone, email, updated_at)
  on table public.profiles to authenticated;
grant update (full_name, company_name, phone, updated_at)
  on table public.profiles to authenticated;

grant select on table public.loan_applications to authenticated;
grant insert (
  user_id,
  company_name,
  equipment_name,
  amount,
  interest_rate,
  repayment_years,
  status
) on table public.loan_applications to authenticated;
grant update (status) on table public.loan_applications to authenticated;
grant delete on table public.loan_applications to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "loans_select_own_or_banker" on public.loan_applications;
drop policy if exists "loans_insert_own_pending" on public.loan_applications;
drop policy if exists "loans_update_banker" on public.loan_applications;
drop policy if exists "loans_delete_banker" on public.loan_applications;

create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = id);

create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "loans_select_own_or_banker"
on public.loan_applications
for select
to authenticated
using (
  (select auth.uid()) = user_id
  or coalesce(
    (select auth.jwt()) -> 'app_metadata' ->> 'role',
    ''
  ) = 'banker'
);

create policy "loans_insert_own_pending"
on public.loan_applications
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and status = 'pending'
);

create policy "loans_update_banker"
on public.loan_applications
for update
to authenticated
using (
  coalesce(
    (select auth.jwt()) -> 'app_metadata' ->> 'role',
    ''
  ) = 'banker'
)
with check (
  coalesce(
    (select auth.jwt()) -> 'app_metadata' ->> 'role',
    ''
  ) = 'banker'
);

create policy "loans_delete_banker"
on public.loan_applications
for delete
to authenticated
using (
  coalesce(
    (select auth.jwt()) -> 'app_metadata' ->> 'role',
    ''
  ) = 'banker'
);

alter table public.loan_applications add column if not exists submitted_at timestamptz;
update public.loan_applications set submitted_at = coalesce(created_at, now()) where submitted_at is null;
alter table public.loan_applications alter column submitted_at set default now();
alter table public.loan_applications alter column submitted_at set not null;

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
