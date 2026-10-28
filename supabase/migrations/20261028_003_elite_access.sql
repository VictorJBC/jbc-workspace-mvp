-- JBC Workspace: Elite membership and row-level visibility.
-- Apply AFTER existing 001 schema, 002 security and demo seed.
-- Run once in Supabase SQL Editor. No existing load is deleted.
begin;

create table public.elite_teams (
  id uuid primary key default gen_random_uuid(),
  department text not null check (department in ('support','operations')),
  team_number integer not null check (team_number between 1 and 4),
  name text generated always as (
    case when department = 'support' then 'Elite Support ' else 'Elite Ops ' end || team_number::text
  ) stored,
  unique(department,team_number),
  unique(id,department)
);

insert into public.elite_teams(department,team_number)
select department, n
from (values ('support'),('operations')) as d(department)
cross join generate_series(1,4) as n;

create table public.user_elite_memberships (
  user_id uuid not null references public.profiles(id) on delete cascade,
  elite_id uuid not null references public.elite_teams(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  primary key(user_id,elite_id)
);

-- Exactly one Support Elite and one Ops Elite per load, each nullable.
-- The FK guarantees the department matches the chosen Elite.
create table public.load_elite_assignments (
  load_id uuid not null references public.loads(id) on delete cascade,
  department text not null check (department in ('support','operations')),
  elite_id uuid not null,
  assigned_at timestamptz not null default now(),
  primary key(load_id,department),
  foreign key(elite_id,department) references public.elite_teams(id,department)
);
create index load_elite_assignments_elite_idx on public.load_elite_assignments(elite_id,load_id);
create index user_elite_memberships_elite_idx on public.user_elite_memberships(elite_id,user_id);

-- SECURITY DEFINER avoids recursive RLS on membership/assignment lookup.
create function public.can_view_load(p_load_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select public.is_staff() and (
   public.has_role('admin') or public.has_role('operations') or public.has_role('accounting')
   or (public.has_role('support') and exists (
     select 1 from public.load_elite_assignments a
     join public.user_elite_memberships m on m.elite_id = a.elite_id
     where a.load_id = p_load_id and a.department = 'support'
       and m.user_id = (select auth.uid())
   ))
 );
$$;

-- Only Ops/Admin can manage load-team assignments. Membership administration
-- is Admin-only; for MVP an administrator may also seed via SQL Editor.
create function public.can_manage_elites() returns boolean
language sql stable security definer set search_path = '' as $$
 select public.is_staff() and public.has_role('admin');
$$;

alter table public.elite_teams enable row level security;
alter table public.user_elite_memberships enable row level security;
alter table public.load_elite_assignments enable row level security;

create policy elite_catalog_read on public.elite_teams for select to authenticated using (public.is_staff());
create policy elite_membership_read on public.user_elite_memberships for select to authenticated
 using (public.can_manage_elites() or (public.is_staff() and user_id = (select auth.uid())));
create policy elite_membership_insert on public.user_elite_memberships for insert to authenticated
 with check (public.can_manage_elites());
create policy elite_membership_delete on public.user_elite_memberships for delete to authenticated
 using (public.can_manage_elites());
create policy load_elites_read on public.load_elite_assignments for select to authenticated
 using (public.can_view_load(load_id));
create policy load_elites_insert on public.load_elite_assignments for insert to authenticated
 with check (public.can_create_load());
create policy load_elites_update on public.load_elite_assignments for update to authenticated
 using (public.can_create_load()) with check (public.can_create_load());
create policy load_elites_delete on public.load_elite_assignments for delete to authenticated
 using (public.can_create_load());

-- Replace permissive policies. Existing loads without Support assignment
-- become invisible to Support, while Operations/Accounting retain visibility.
drop policy if exists loads_read on public.loads;
create policy loads_read on public.loads for select to authenticated
 using (public.can_view_load(id));
drop policy if exists loads_update on public.loads;
create policy loads_update on public.loads for update to authenticated
 using (public.can_view_load(id)) with check (public.can_view_load(id));

-- Child tables must not leak inaccessible load data.
drop policy if exists stops_read on public.stops;
create policy stops_read on public.stops for select to authenticated using (public.can_view_load(load_id));
drop policy if exists stops_insert on public.stops;
create policy stops_insert on public.stops for insert to authenticated with check (public.can_view_load(load_id));
drop policy if exists stops_update on public.stops;
create policy stops_update on public.stops for update to authenticated
 using (public.can_view_load(load_id)) with check (public.can_view_load(load_id));
drop policy if exists stops_delete on public.stops;
create policy stops_delete on public.stops for delete to authenticated using (public.can_view_load(load_id));

drop policy if exists tasks_read on public.tasks;
create policy tasks_read on public.tasks for select to authenticated using (public.can_view_load(load_id));
drop policy if exists tasks_insert on public.tasks;
create policy tasks_insert on public.tasks for insert to authenticated with check (public.can_view_load(load_id));
drop policy if exists tasks_update on public.tasks;
create policy tasks_update on public.tasks for update to authenticated
 using (public.can_view_load(load_id)) with check (public.can_view_load(load_id));
drop policy if exists tasks_delete on public.tasks;
create policy tasks_delete on public.tasks for delete to authenticated using (public.can_view_load(load_id));

drop policy if exists notes_read on public.load_notes;
create policy notes_read on public.load_notes for select to authenticated using (public.can_view_load(load_id));
drop policy if exists notes_insert on public.load_notes;
create policy notes_insert on public.load_notes for insert to authenticated with check (public.can_view_load(load_id));
drop policy if exists notes_update on public.load_notes;
create policy notes_update on public.load_notes for update to authenticated
 using (public.can_view_load(load_id)) with check (public.can_view_load(load_id));

drop policy if exists assignments_read on public.load_assignments;
create policy assignments_read on public.load_assignments for select to authenticated using (public.can_view_load(load_id));

-- Keep financial access limited to Accounting/Admin, even for users with Support membership.
drop policy if exists invoices_read on public.invoices;
create policy invoices_read on public.invoices for select to authenticated
 using (public.can_account() and public.can_view_load(load_id));

revoke all on public.elite_teams,public.user_elite_memberships,public.load_elite_assignments from anon,authenticated;
grant select on public.elite_teams to authenticated;
grant select,insert,delete on public.user_elite_memberships to authenticated;
grant select,insert,update,delete on public.load_elite_assignments to authenticated;
revoke all on function public.can_view_load(uuid), public.can_manage_elites() from public,anon,authenticated;
grant execute on function public.can_view_load(uuid), public.can_manage_elites() to authenticated;

-- Audit membership and load-team assignment changes with existing trigger.
create trigger audit_user_elite_memberships after insert or update or delete on public.user_elite_memberships
 for each row execute function public.capture_activity();
create trigger audit_load_elite_assignments after insert or update or delete on public.load_elite_assignments
 for each row execute function public.capture_activity();

commit;
