-- JBC Workspace MVP / Patch v3 Stage 2B (REVISED)
-- Prerequisites: 001, 002, 003 elite preparation, 004 memberships.
-- IMPORTANT: Run as one SQL Editor query. This changes row visibility immediately.
-- Existing broad UPDATE permissions are NOT hardened here; separate patch required.
BEGIN;
DO $$
BEGIN
 IF to_regclass('public.elite_teams') IS NULL OR
    to_regclass('public.user_elite_memberships') IS NULL OR
    to_regclass('public.load_elite_assignments') IS NULL THEN
   RAISE EXCEPTION 'Elite preparation missing (003).';
 END IF;
 IF EXISTS (
   SELECT 1 FROM public.profiles p JOIN public.user_roles r ON r.user_id=p.id
   WHERE p.active AND r.role='support'
     AND NOT EXISTS (SELECT 1 FROM public.user_elite_memberships m
       JOIN public.elite_teams e ON e.id=m.elite_id
       WHERE m.user_id=p.id AND e.department='support')
 ) THEN
   RAISE EXCEPTION 'Active Support user without Support Elite membership. Aborting.';
 END IF;
 IF EXISTS (
   SELECT 1 FROM public.loads l WHERE l.load_number IN
    ('DEMO-OPS-001','DEMO-OPS-002','DEMO-SUP-001','DEMO-SUP-002','DEMO-ACC-001','DEMO-ACC-002')
   AND NOT EXISTS (SELECT 1 FROM public.load_elite_assignments a
      WHERE a.load_id=l.id AND a.department='support')
 ) THEN
   RAISE EXCEPTION 'Demo load missing Support Elite assignment. Aborting.';
 END IF;
END $$;

-- SECURITY DEFINER reads the membership/assignment tables, which intentionally
-- have no client grants. auth.uid() remains the actual signed-in user's ID.
CREATE OR REPLACE FUNCTION public.can_see_load(p_load_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT COALESCE(
  p_load_id IS NOT NULL AND public.is_staff() AND (
    public.has_role('operations') OR public.has_role('accounting') OR public.has_role('admin')
    OR (public.has_role('support') AND EXISTS (
      SELECT 1 FROM public.load_elite_assignments a
      JOIN public.elite_teams e ON e.id=a.elite_id AND e.department='support'
      JOIN public.user_elite_memberships m ON m.elite_id=a.elite_id
      WHERE a.load_id=p_load_id AND a.department='support'
        AND m.user_id=(SELECT auth.uid())
    ))
  ), false);
$$;
REVOKE ALL ON FUNCTION public.can_see_load(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_see_load(uuid) TO authenticated;

-- Remove only known policies; preflight below aborts if unexpected policies exist.
DO $$
DECLARE rec record;
BEGIN
 FOR rec IN
  SELECT tablename, policyname FROM pg_policies
  WHERE schemaname='public' AND tablename IN
   ('loads','load_assignments','stops','tasks','load_notes')
   AND policyname NOT IN (
    'loads_create','loads_read','loads_update',
    'assignments_read','assignments_insert','assignments_update','assignments_delete',
    'stops_read','stops_insert','stops_update','stops_delete',
    'tasks_read','tasks_insert','tasks_update','tasks_delete',
    'notes_read','notes_insert','notes_update')
 LOOP
  RAISE EXCEPTION 'Unexpected policy %.%: review before activation',rec.tablename,rec.policyname;
 END LOOP;
END $$;

DROP POLICY IF EXISTS loads_read ON public.loads;
CREATE POLICY loads_read ON public.loads FOR SELECT TO authenticated
 USING (public.can_see_load(id));
DROP POLICY IF EXISTS loads_update ON public.loads;
CREATE POLICY loads_update ON public.loads FOR UPDATE TO authenticated
 USING (public.can_see_load(id)) WITH CHECK (public.can_see_load(id));
-- loads_create stays limited to can_create_load().

DROP POLICY IF EXISTS assignments_read ON public.load_assignments;
CREATE POLICY assignments_read ON public.load_assignments FOR SELECT TO authenticated
 USING (public.can_see_load(load_id));
-- Existing assignments write policies remain restricted to can_create_load().

DROP POLICY IF EXISTS stops_read ON public.stops;
CREATE POLICY stops_read ON public.stops FOR SELECT TO authenticated USING (public.can_see_load(load_id));
DROP POLICY IF EXISTS stops_insert ON public.stops;
CREATE POLICY stops_insert ON public.stops FOR INSERT TO authenticated WITH CHECK (public.can_see_load(load_id));
DROP POLICY IF EXISTS stops_update ON public.stops;
CREATE POLICY stops_update ON public.stops FOR UPDATE TO authenticated USING (public.can_see_load(load_id)) WITH CHECK (public.can_see_load(load_id));
DROP POLICY IF EXISTS stops_delete ON public.stops;
CREATE POLICY stops_delete ON public.stops FOR DELETE TO authenticated USING (public.can_see_load(load_id));

DROP POLICY IF EXISTS tasks_read ON public.tasks;
CREATE POLICY tasks_read ON public.tasks FOR SELECT TO authenticated USING (public.can_see_load(load_id));
DROP POLICY IF EXISTS tasks_insert ON public.tasks;
CREATE POLICY tasks_insert ON public.tasks FOR INSERT TO authenticated WITH CHECK (public.can_see_load(load_id));
DROP POLICY IF EXISTS tasks_update ON public.tasks;
CREATE POLICY tasks_update ON public.tasks FOR UPDATE TO authenticated USING (public.can_see_load(load_id)) WITH CHECK (public.can_see_load(load_id));
DROP POLICY IF EXISTS tasks_delete ON public.tasks;
CREATE POLICY tasks_delete ON public.tasks FOR DELETE TO authenticated USING (public.can_see_load(load_id));

DROP POLICY IF EXISTS notes_read ON public.load_notes;
CREATE POLICY notes_read ON public.load_notes FOR SELECT TO authenticated USING (public.can_see_load(load_id));
DROP POLICY IF EXISTS notes_insert ON public.load_notes;
CREATE POLICY notes_insert ON public.load_notes FOR INSERT TO authenticated WITH CHECK (public.can_see_load(load_id));
DROP POLICY IF EXISTS notes_update ON public.load_notes;
CREATE POLICY notes_update ON public.load_notes FOR UPDATE TO authenticated USING (public.can_see_load(load_id)) WITH CHECK (public.can_see_load(load_id));

-- Financial policies remain can_account() only; accounting/admin have global
-- can_see_load(), so no additional invoice/payment policy changes are needed.
-- Audit stays admin-only. No browser grants to elite membership/assignment tables.
COMMIT;

-- Diagnostic (SQL Editor runs as privileged role; NOT a user-specific RLS test).
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies WHERE schemaname='public'
AND tablename IN ('loads','load_assignments','stops','tasks','load_notes')
ORDER BY tablename,policyname;
