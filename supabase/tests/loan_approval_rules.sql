begin;
do $$
declare actor uuid;
begin
 select id into actor from auth.users where coalesce(raw_app_meta_data->>'role','') <> 'banker' limit 1;
 if actor is null then raise exception 'No SME test actor'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','app_metadata',jsonb_build_object('role','sme'))::text,true);
end $$;
set local role authenticated;
do $$
declare r jsonb; target uuid; other uuid; original_date timestamptz; n integer; actor uuid := auth.uid(); test_amount text;
begin
 insert into public.loan_applications(user_id,company_name,equipment_name,amount,interest_rate,repayment_years,status)
 values(actor,'Task7 transactional test','Robotic Arm',5000.00,4.5,5,'pending') returning id,submitted_at into target,original_date;
 if original_date is null then raise exception 'submitted date missing'; end if;
 foreach test_amount in array array['10000','-100.00','4500.00','600001.00','abc'] loop
   begin
     perform public.update_pending_loan(target,'Test','Robotic Arm',test_amount,4.5,5);
     raise exception 'invalid amount accepted';
   exception when raise_exception then
     if sqlerrm <> 'loan_invalid_details' then raise; end if;
   end;
 end loop;
 begin
   perform public.update_pending_loan(target,repeat('x',51),'Robotic Arm','5000.00',4.5,5);
   raise exception 'invalid company accepted';
 exception when raise_exception then
   if sqlerrm <> 'loan_invalid_details' then raise; end if;
 end;
 for n in 1..5 loop
   r := public.update_pending_loan(target,'Test ' || n,'Robotic Arm','10000.50',4.5,5);
   if r->>'company_name' <> 'Test ' || n then raise exception 'repeated edit failed'; end if;
   if (r->>'submitted_at')::timestamptz <> original_date then raise exception 'submitted date changed'; end if;
 end loop;
 update public.loan_applications set amount=5100 where id=target;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated','app_metadata',jsonb_build_object('role','sme'))::text,true);
 begin
   perform public.update_pending_loan(target,'Intruder','Robotic Arm','5000.00',4.5,5);
   raise exception 'owner isolation failed';
 exception when raise_exception then
   if sqlerrm <> 'loan_not_found' then raise; end if;
 end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','app_metadata',jsonb_build_object('role','banker'))::text,true);
 update public.loan_applications set status='approved' where id=target;
 begin
   update public.loan_applications set amount=7000 where id=target;
   raise exception 'approved edit accepted';
 exception when raise_exception then
   if sqlerrm <> 'loan_not_pending' then raise; end if;
 end;
 begin
   perform public.delete_pending_loan(target);
   raise exception 'approved deletion accepted';
 exception when raise_exception then
   if sqlerrm <> 'loan_not_pending' then raise; end if;
 end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','app_metadata',jsonb_build_object('role','sme'))::text,true);
 insert into public.loan_applications(user_id,company_name,equipment_name,amount,interest_rate,repayment_years,status)
 values(actor,'Task7 delete test','Robotic Arm',5000.00,4.5,5,'pending') returning id into other;
 perform public.delete_pending_loan(other);
 select count(*) into n from public.loan_applications where id=other;
 if n <> 0 then raise exception 'pending deletion failed'; end if;
end $$;
rollback;
select 'PASS: dates, exact RM format, ranges, company, unlimited edits, owner isolation, approved protection, pending deletion; rolled back' as verification;
