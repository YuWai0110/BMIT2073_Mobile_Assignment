select n.nspname as schema_name, r.relname as table_name, c.conname,
       pg_get_constraintdef(c.oid) as definition
from pg_constraint c
join pg_class r on r.oid=c.conrelid
join pg_namespace n on n.oid=r.relnamespace
where c.contype='f' and c.confrelid='auth.users'::regclass
order by 1,2,3;

select
  (select count(*) from auth.users) as users,
  (select count(*) from public.profiles) as profiles,
  (select count(*) from public.loan_applications) as loans,
  (select count(*) from public.profiles p
   where not exists(select 1 from auth.users u where u.id=p.id)) as orphan_profiles,
  (select count(*) from public.loan_applications l
   where not exists(select 1 from auth.users u where u.id=l.user_id)) as orphan_loans;

begin;
do $$
declare
  test_user uuid;
  role_name text;
  original_users bigint := (select count(*) from auth.users);
  original_profiles bigint := (select count(*) from public.profiles);
  original_loans bigint := (select count(*) from public.loan_applications);
begin
  foreach role_name in array array['postgres'] loop
    test_user := gen_random_uuid();
    insert into auth.users(id, email, raw_user_meta_data, raw_app_meta_data)
    values(test_user, 'cascade-test-' || test_user || '@example.invalid', '{}', '{}');
    if not exists(select 1 from public.profiles where id = test_user) then
      raise exception 'Test profile missing';
    end if;
    insert into public.loan_applications
      (user_id, company_name, equipment_name, amount, interest_rate, repayment_years, status)
    select test_user, 'Cascade Test', 'Test Equipment', 5000, 3, 3, status
    from unnest(array['pending','approved','rejected']) as status;
    begin
      delete from public.loan_applications where user_id = test_user and status = 'approved';
      raise exception 'Direct approved loan deletion incorrectly allowed';
    exception when others then
      if sqlerrm <> 'loan_not_pending' then raise; end if;
    end;
    execute format('set local role %I', role_name);
    delete from auth.users where id = test_user;
    execute 'reset role';
    if exists(select 1 from auth.users where id = test_user)
       or exists(select 1 from public.profiles where id = test_user)
       or exists(select 1 from public.loan_applications where user_id = test_user) then
      raise exception 'Cascade verification failed for role %', role_name;
    end if;
  end loop;
  if (select count(*) from auth.users) <> original_users
     or (select count(*) from public.profiles) <> original_profiles
     or (select count(*) from public.loan_applications) <> original_loans then
    raise exception 'Existing row counts changed';
  end if;
end;
$$;
select 'PASS: administrator cascades all loan statuses; direct approved deletion remains blocked' as result,
  (select count(*) from public.profiles p where not exists(select 1 from auth.users u where u.id=p.id)) as orphan_profiles,
  (select count(*) from public.loan_applications l where not exists(select 1 from auth.users u where u.id=l.user_id)) as orphan_loans;
rollback;
