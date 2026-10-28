-- JBC Workspace MVP - permissions and payment integrity, revised v2.
-- Run after 001_schema.sql. New/empty database only.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

create function public.has_role(p_role text) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.user_roles r where r.user_id=(select auth.uid()) and r.role=p_role)
$$;
create function public.is_staff() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.active)
 and exists(select 1 from public.user_roles r where r.user_id=(select auth.uid())
 and r.role in ('support','operations','accounting','admin'))
$$;
create function public.can_account() returns boolean
language sql stable security definer set search_path = '' as $$
 select public.is_staff() and (public.has_role('accounting') or public.has_role('admin'))
$$;
create function public.can_create_load() returns boolean
language sql stable security definer set search_path = '' as $$
 select public.is_staff() and (public.has_role('operations') or public.has_role('admin'))
$$;

-- Newly registered users remain inactive until explicitly approved by administrator.
create function public.on_auth_user_created() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,display_name,active)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),false)
 on conflict (id) do nothing;
 return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.on_auth_user_created();
-- Handle accounts created before this trigger was installed.
insert into public.profiles(id,display_name,active)
select id,coalesce(raw_user_meta_data->>'full_name',''),false from auth.users
on conflict (id) do nothing;

-- The database, not the browser, assigns created_by.
create function public.stamp_actor() returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_op='INSERT' then new.created_by := (select auth.uid());
 elsif tg_op='UPDATE' then new.created_by := old.created_by;
 end if;
 return new;
end; $$;
do $$ declare t text; begin
 foreach t in array array['loads','tasks','load_notes','invoices'] loop
  execute format('create trigger %I before insert or update on public.%I for each row execute function public.stamp_actor()', 'stamp_'||t,t);
 end loop;
end $$;
create trigger stamp_invoice_payment before insert on public.invoice_payments
for each row execute function public.stamp_actor();

-- Invoice row lock serializes payment inserts for the same invoice.
-- An invoice UPDATE takes the same row lock, preventing total/payment races.
create function public.validate_invoice_payment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_total numeric; v_paid numeric; v_status text;
begin
 select total_amount,billing_status into v_total,v_status
 from public.invoices where id=new.invoice_id for update;
 if not found then raise exception 'Invoice not found'; end if;
 if v_status='Canceled' then raise exception 'Cannot pay a canceled invoice'; end if;
 select coalesce(sum(amount),0) into v_paid from public.invoice_payments
 where invoice_id=new.invoice_id;
 if v_paid + new.amount > v_total then raise exception 'Payment exceeds invoice balance'; end if;
 return new;
end; $$;
create trigger validate_invoice_payment before insert on public.invoice_payments
for each row execute function public.validate_invoice_payment();

create function public.validate_invoice_total() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_paid numeric;
begin
 -- The UPDATE already locks the invoice row; payment inserts must wait for it.
 select coalesce(sum(amount),0) into v_paid from public.invoice_payments where invoice_id=new.id;
 if new.total_amount < v_paid then raise exception 'Invoice total below paid amount'; end if;
 if new.billing_status='Canceled' and v_paid>0 then raise exception 'Cannot cancel invoice with payments'; end if;
 if new.invoice_side <> old.invoice_side or new.currency <> old.currency then
  if v_paid>0 then raise exception 'Cannot change invoice side/currency after payments'; end if;
 end if;
 return new;
end; $$;
create trigger validate_invoice_total before update on public.invoices
for each row execute function public.validate_invoice_total();

-- For critical payment operations the browser supplies a UUID request_id.
-- It is a correlation/idempotency identifier, NOT authentication.
-- One RPC invocation = one transaction, so SET LOCAL is safely scoped.
create function public.record_invoice_payment(
 p_invoice_id uuid, p_amount numeric, p_paid_on date,
 p_paid_at timestamptz default null, p_reference text default '',
 p_notes text default '', p_request_id uuid default null
) returns uuid language plpgsql security invoker set search_path = '' as $$
declare v_id uuid; v_existing public.invoice_payments%rowtype;
begin
 if not public.can_account() then raise exception 'Not authorized'; end if;
 if p_request_id is null then raise exception 'request_id is required'; end if;
 if p_invoice_id is null or p_amount is null or p_paid_on is null then
  raise exception 'invoice_id, amount and paid_on are required';
 end if;
 -- Avoid duplicate payment when the UI retries a completed request.
 select * into v_existing from public.invoice_payments where request_id=p_request_id;
 if found then
  if v_existing.invoice_id=p_invoice_id and v_existing.amount=p_amount
    and v_existing.paid_on=p_paid_on and v_existing.paid_at is not distinct from p_paid_at
    and v_existing.reference=coalesce(p_reference,'') and v_existing.notes=coalesce(p_notes,'')
  then return v_existing.id;
  else raise exception 'request_id already used for a different payment'; end if;
 end if;
 perform set_config('app.request_id',p_request_id::text,true);
 insert into public.invoice_payments(invoice_id,amount,paid_on,paid_at,reference,notes,request_id)
 values(p_invoice_id,p_amount,p_paid_on,p_paid_at,coalesce(p_reference,''),coalesce(p_notes,''),p_request_id)
 returning id into v_id;
 return v_id;
exception when unique_violation then
 -- A simultaneous retry may collide; report a retryable conflict, never create a second payment.
 raise exception 'Duplicate request_id; refresh payment list before retrying';
end; $$;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.loads enable row level security;
alter table public.load_assignments enable row level security;
alter table public.stops enable row level security;
alter table public.tasks enable row level security;
alter table public.load_notes enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_payments enable row level security;
alter table public.activity_events enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (public.is_staff());
create policy roles_read on public.user_roles for select to authenticated using (public.is_staff());
create policy roles_admin_insert on public.user_roles for insert to authenticated
 with check (public.is_staff() and public.has_role('admin'));
create policy roles_admin_delete on public.user_roles for delete to authenticated
 using (public.is_staff() and public.has_role('admin'));
-- Profile activation is performed by a trusted admin in SQL Editor for MVP.

create policy loads_read on public.loads for select to authenticated using (public.is_staff());
create policy loads_create on public.loads for insert to authenticated with check (public.can_create_load());
create policy loads_update on public.loads for update to authenticated
 using (public.is_staff()) with check (public.is_staff());
-- No loads DELETE policy or grant: archive/restore instead.
create policy assignments_read on public.load_assignments for select to authenticated using (public.is_staff());
create policy assignments_insert on public.load_assignments for insert to authenticated with check (public.can_create_load());
create policy assignments_update on public.load_assignments for update to authenticated
 using (public.can_create_load()) with check (public.can_create_load());
create policy assignments_delete on public.load_assignments for delete to authenticated using (public.can_create_load());
create policy stops_read on public.stops for select to authenticated using (public.is_staff());
create policy stops_insert on public.stops for insert to authenticated with check (public.is_staff());
create policy stops_update on public.stops for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy stops_delete on public.stops for delete to authenticated using (public.is_staff());
create policy tasks_read on public.tasks for select to authenticated using (public.is_staff());
create policy tasks_insert on public.tasks for insert to authenticated with check (public.is_staff());
create policy tasks_update on public.tasks for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy tasks_delete on public.tasks for delete to authenticated using (public.is_staff());
create policy notes_read on public.load_notes for select to authenticated using (public.is_staff());
create policy notes_insert on public.load_notes for insert to authenticated with check (public.is_staff());
create policy notes_update on public.load_notes for update to authenticated using (public.is_staff()) with check (public.is_staff());
-- Notes are retained; no client delete permission.
create policy invoices_read on public.invoices for select to authenticated using (public.can_account());
create policy invoices_insert on public.invoices for insert to authenticated with check (public.can_account());
create policy invoices_update on public.invoices for update to authenticated
 using (public.can_account()) with check (public.can_account());
create policy payments_read on public.invoice_payments for select to authenticated using (public.can_account());
-- Payments are inserted ONLY through record_invoice_payment RPC, not direct table grants.
create policy payments_insert on public.invoice_payments for insert to authenticated with check (public.can_account());
create policy audit_read on public.activity_events for select to authenticated
 using (public.is_staff() and public.has_role('admin'));

-- Functions created above default to PUBLIC EXECUTE in PostgreSQL; revoke that default.
revoke all on all functions in schema public from public, anon, authenticated;

-- Grants: RLS controls rows; grants control available operations.
grant usage on schema public to authenticated;
grant execute on function public.has_role(text),public.is_staff(),public.can_account(),public.can_create_load() to authenticated;
grant select on public.profiles,public.user_roles,public.loads,public.load_assignments,public.stops,public.tasks,public.load_notes to authenticated;
grant insert,update on public.loads to authenticated;
grant insert,update,delete on public.load_assignments,public.stops,public.tasks to authenticated;
grant insert,update on public.load_notes to authenticated;
grant insert,delete on public.user_roles to authenticated;
grant select,insert,update on public.invoices to authenticated;
grant select,insert on public.invoice_payments to authenticated;
grant select on public.invoice_balances to authenticated;
grant select on public.activity_events to authenticated;
grant usage,select on sequence public.activity_events_id_seq to authenticated;
grant execute on function public.record_invoice_payment(uuid,numeric,date,timestamptz,text,text,uuid) to authenticated;
-- Restrict direct payment insert: RPC is SECURITY INVOKER, so it requires INSERT.
-- Direct insert remains technically possible for Accounting; it is blocked if request_id absent.
create function public.require_payment_request_id() returns trigger
language plpgsql set search_path = '' as $$
begin
 if new.request_id is null then raise exception 'Use record_invoice_payment RPC with request_id'; end if;
 return new;
end; $$;
create trigger require_payment_request_id before insert on public.invoice_payments
for each row execute function public.require_payment_request_id();
-- No grants to anon; no direct modifications to audit.
