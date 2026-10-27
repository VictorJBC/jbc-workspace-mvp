-- JBC Workspace MVP: schema. Apply before 002_security.sql.
create extension if not exists pgcrypto;

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '',
 active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.user_roles (
 user_id uuid not null references public.profiles(id) on delete cascade,
 role text not null check (role in ('support','operations','accounting','admin')),
 primary key (user_id, role)
);
create table public.loads (
 id uuid primary key default gen_random_uuid(),
 load_number text unique,
 customer_name text not null default '',
 carrier_name text not null default '',
 driver_name text not null default '',
 driver_phone text not null default '',
 equipment text not null default '',
 po_number text not null default '',
 ops_status text not null default 'Dispatched' check (ops_status in ('Dispatched','At Pickup','Picked Up','En Route','At Delivery','Delivered','Route Complete','On Hold')),
 tracking_status text not null default '',
 tracking_url text,
 tracking_updated_at timestamptz,
 current_location text not null default '',
 eta timestamptz,
 pickup_at timestamptz,
 delivery_at timestamptz,
 appointment_note text not null default '',
 handoff text not null default '',
 owner_user_id uuid references public.profiles(id) on delete set null,
 elite_team text,
 broker_name text not null default '',
 broker_contact text not null default '',
 broker_phone text not null default '',
 dispatcher text not null default '',
 miles_out numeric(10,2) check (miles_out is null or miles_out >= 0),
 route_complete boolean not null default false,
 completed_at timestamptz,
 version bigint not null default 1,
 created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint load_number_nonblank check (load_number is null or length(btrim(load_number)) > 0)
);
create table public.load_assignments (
 id uuid primary key default gen_random_uuid(),
 load_id uuid not null references public.loads(id) on delete cascade,
 user_id uuid references public.profiles(id) on delete cascade,
 team_name text,
 created_at timestamptz not null default now(),
 check ((user_id is null) <> (team_name is null))
);
create unique index load_assignments_user_unique on public.load_assignments(load_id,user_id) where user_id is not null;
create unique index load_assignments_team_unique on public.load_assignments(load_id,team_name) where team_name is not null;
create table public.stops (
 id uuid primary key default gen_random_uuid(),
 load_id uuid not null references public.loads(id) on delete cascade,
 stop_order integer not null check (stop_order > 0),
 stop_type text not null check (stop_type in ('Pickup','Intermediate','Delivery')),
 name text not null default '',
 address text not null default '',
 appointment_at timestamptz,
 appointment_text text not null default '',
 status text not null default 'Pending' check (status in ('Pending','At Pickup','At Delivery','Visited','Completed')),
 arrived_at timestamptz,
 completed_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(load_id,stop_order),
 check (status <> 'At Pickup' or stop_type = 'Pickup'),
 check (status <> 'At Delivery' or stop_type = 'Delivery')
);
create table public.tasks (
 id uuid primary key default gen_random_uuid(),
 load_id uuid not null references public.loads(id) on delete cascade,
 title text not null check (length(btrim(title)) > 0),
 description text not null default '',
 status text not null default 'Open' check (status in ('Open','In Progress','Blocked','Completed')),
 assigned_to uuid references public.profiles(id) on delete set null,
 due_at timestamptz,
 completed_at timestamptz,
 created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table public.load_notes (
 id uuid primary key default gen_random_uuid(),
 load_id uuid not null references public.loads(id) on delete cascade,
 body text not null check (length(btrim(body)) > 0),
 created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
-- One row per invoice. Amounts are denominated in currency and must be nonnegative.
create table public.invoices (
 id uuid primary key default gen_random_uuid(),
 load_id uuid not null references public.loads(id) on delete restrict,
 invoice_side text not null check (invoice_side in ('customer','carrier')),
 invoice_number text not null,
 counterparty_name text not null default '',
 currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
 total_amount numeric(14,2) not null check (total_amount >= 0),
 billing_status text not null default 'Draft' check (billing_status in ('Draft','Ready for Billing','Processing','Completed','Canceled')),
 issued_at date,
 due_at date,
 notes text not null default '',
 created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(invoice_side,counterparty_name,invoice_number),
 check (length(btrim(invoice_number)) > 0)
);
create table public.invoice_payments (
 id uuid primary key default gen_random_uuid(),
 invoice_id uuid not null references public.invoices(id) on delete restrict,
 amount numeric(14,2) not null check (amount > 0),
 paid_on date not null,
 reference text not null default '',
 notes text not null default '',
 created_by uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default now()
);
-- Payment totals are derived, never edited by the browser.
create view public.invoice_balances with (security_invoker = true) as
select i.id, i.load_id, i.invoice_side, i.invoice_number, i.currency,
 i.total_amount, coalesce(sum(p.amount),0)::numeric(14,2) as amount_paid,
 (i.total_amount - coalesce(sum(p.amount),0))::numeric(14,2) as balance_due,
 (i.total_amount > 0 and coalesce(sum(p.amount),0) >= i.total_amount) as is_paid,
 case when i.total_amount > 0 and coalesce(sum(p.amount),0) >= i.total_amount
      then max(p.created_at) else null end as paid_at
from public.invoices i left join public.invoice_payments p on p.invoice_id=i.id
group by i.id;
-- Database audit: immutable from API roles; old/new JSON per write.
create table public.activity_events (
 id bigint generated always as identity primary key,
 occurred_at timestamptz not null default clock_timestamp(),
 actor_user_id uuid,
 entity_table text not null,
 entity_id text not null,
 action text not null check (action in ('INSERT','UPDATE','DELETE')),
 old_data jsonb,
 new_data jsonb,
 request_id text,
 transaction_id bigint not null default txid_current()
);
create index tasks_load_status_idx on public.tasks(load_id,status);
create index tasks_assignee_due_idx on public.tasks(assigned_to,due_at);
create index stops_load_order_idx on public.stops(load_id,stop_order);
create index invoices_load_side_idx on public.invoices(load_id,invoice_side);
create index payments_invoice_idx on public.invoice_payments(invoice_id);
create index activity_entity_idx on public.activity_events(entity_table,entity_id,occurred_at desc);
create index loads_ops_status_idx on public.loads(ops_status);

create function public.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin
 new.updated_at := now();
 if tg_table_name = 'loads' and tg_op = 'UPDATE' then
  new.version := old.version + 1;
 end if;
 return new;
end; $$;
-- Avoid untrusted request headers causing audit failure: request_id is optional.
create or replace function public.capture_activity() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_old jsonb; v_new jsonb; v_id text;
begin
 v_old := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end;
 v_new := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end;
 if tg_op = 'UPDATE' and v_old = v_new then return new; end if;
 v_id := coalesce(v_new->>'id',v_old->>'id',v_new->>'user_id',v_old->>'user_id','unknown');
 insert into public.activity_events(actor_user_id,entity_table,entity_id,action,old_data,new_data,transaction_id)
 values((select auth.uid()),tg_table_name,v_id,tg_op,v_old,v_new,txid_current());
 if tg_op='DELETE' then return old; else return new; end if;
end; $$;
-- Audit includes financial/payment edits and authorization changes.
do $$ declare t text; begin
 foreach t in array array['profiles','user_roles','loads','load_assignments','stops','tasks','load_notes','invoices','invoice_payments'] loop
  if t not in ('user_roles','invoice_payments','load_assignments') then
   execute format('create trigger %I before update on public.%I for each row execute function public.touch_updated_at()', 'touch_'||t,t);
  end if;
  execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.capture_activity()', 'audit_'||t,t);
 end loop;
end $$;
