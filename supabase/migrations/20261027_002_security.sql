-- JBC Workspace MVP: least-privilege Data API grants and RLS.
-- Do NOT use the browser to assign roles; bootstrap via SQL Editor only.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

create function public.has_role(p_role text) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists (select 1 from public.user_roles r where r.user_id=(select auth.uid()) and r.role=p_role)
$$;
create function public.is_staff() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.active)
   and exists (select 1 from public.user_roles r where r.user_id=(select auth.uid()) and r.role in ('support','operations','accounting','admin'))
$$;
create function public.can_account() returns boolean
language sql stable security definer set search_path = '' as $$
 select public.is_staff() and (public.has_role('accounting') or public.has_role('admin'))
$$;
create function public.can_create_load() returns boolean
language sql stable security definer set search_path = '' as $$
 select public.is_staff() and (public.has_role('operations') or public.has_role('admin'))
$$;
-- New Auth users get inactive profiles until an administrator explicitly approves them.
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

-- Prevent impersonating another author and accidental changes to immutable authors.
create function public.stamp_actor() returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_op = 'INSERT' then new.created_by := (select auth.uid());
 elsif tg_op = 'UPDATE' then new.created_by := old.created_by;
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

-- Reject overpayments with row-level invoice locking; prevents concurrent payment races.
create function public.validate_invoice_payment() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_total numeric; v_paid numeric; v_status text;
begin
 select total_amount,billing_status into v_total,v_status from public.invoices where id=new.invoice_id for update;
 if not found then raise exception 'Invoice not found'; end if;
 if v_status='Canceled' then raise exception 'Cannot pay a canceled invoice'; end if;
 select coalesce(sum(amount),0) into v_paid from public.invoice_payments where invoice_id=new.invoice_id;
 if v_paid + new.amount > v_total then raise exception 'Payment exceeds invoice balance'; end if;
 return new;
end; $$;
create trigger validate_invoice_payment before insert on public.invoice_payments
for each row execute function public.validate_invoice_payment();
-- Invoice total cannot be lowered below already registered payments.
create function public.validate_invoice_total() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_paid numeric;
begin
 select coalesce(sum(amount),0) into v_paid from public.invoice_payments where invoice_id=new.id;
 if new.total_amount < v_paid then raise exception 'Invoice total below paid amount'; end if;
 if new.billing_status='Canceled' and v_paid>0 then raise exception 'Cannot cancel invoice with payments'; end if;
 return new;
end; $$;
create trigger validate_invoice_total before update on public.invoices
for each row execute function public.validate_invoice_total();

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

-- Staff can see active colleagues and their roles; only admins can change roles.
create policy profiles_read on public.profiles for select to authenticated using (public.is_staff());
create policy roles_read on public.user_roles for select to authenticated using (public.is_staff());
create policy roles_admin_insert on public.user_roles for insert to authenticated with check (public.is_staff() and public.has_role('admin'));
create policy roles_admin_delete on public.user_roles for delete to authenticated using (public.is_staff() and public.has_role('admin'));
-- Profile activation/changes are done by admin via SQL Editor for MVP.

create policy loads_read on public.loads for select to authenticated using (public.is_staff());
create policy loads_create on public.loads for insert to authenticated with check (public.can_create_load());
create policy loads_update on public.loads for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy loads_delete on public.loads for delete to authenticated using (public.is_staff() and public.has_role('admin'));

create policy assignments_read on public.load_assignments for select to authenticated using (public.is_staff());
create policy assignments_write on public.load_assignments for all to authenticated using (public.can_create_load()) with check (public.can_create_load());
create policy stops_read on public.stops for select to authenticated using (public.is_staff());
create policy stops_write on public.stops for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy tasks_read on public.tasks for select to authenticated using (public.is_staff());
create policy tasks_write on public.tasks for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy notes_read on public.load_notes for select to authenticated using (public.is_staff());
create policy notes_write on public.load_notes for insert to authenticated with check (public.is_staff());
create policy notes_update on public.load_notes for update to authenticated using (public.is_staff()) with check (public.is_staff());
-- Notes are retained for audit; no deletion via client.

create policy invoices_read on public.invoices for select to authenticated using (public.can_account());
create policy invoices_insert on public.invoices for insert to authenticated with check (public.can_account());
create policy invoices_update on public.invoices for update to authenticated using (public.can_account()) with check (public.can_account());
create policy payments_read on public.invoice_payments for select to authenticated using (public.can_account());
create policy payments_insert on public.invoice_payments for insert to authenticated with check (public.can_account());
-- Payments are append-only in MVP; corrections require an audited admin workflow.
create policy audit_read on public.activity_events for select to authenticated using (public.is_staff() and public.has_role('admin'));

-- Explicit grants because automatic table exposure was disabled.
grant usage on schema public to authenticated;
grant execute on function public.has_role(text), public.is_staff(), public.can_account(), public.can_create_load() to authenticated;
grant select on public.profiles,public.user_roles,public.loads,public.load_assignments,public.stops,public.tasks,public.load_notes to authenticated;
grant insert,update,delete on public.loads,public.load_assignments,public.stops,public.tasks to authenticated;
grant insert,update on public.load_notes to authenticated;
grant insert,delete on public.user_roles to authenticated;
grant select,insert,update on public.invoices to authenticated;
grant select,insert on public.invoice_payments to authenticated;
grant select on public.invoice_balances to authenticated;
grant select on public.activity_events to authenticated;
grant usage,select on sequence public.activity_events_id_seq to authenticated;
-- No grants for anon; no direct insert/update/delete on audit.
