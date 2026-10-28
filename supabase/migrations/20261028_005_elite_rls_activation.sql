-- Patch v3 stage 2B: activate Support row-level security. Run ONLY after 004 and preflight.
-- Preflight: 004 must have assigned Support membership to each active Support account.
-- Existing Ops/Accounting/Admin visibility remains global. No browser grants for membership tables.
BEGIN;
CREATE OR REPLACE FUNCTION public.can_see_load(p_load_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT public.is_staff() AND (
   public.has_role('operations') OR public.has_role('accounting') OR public.has_role('admin')
   OR (public.has_role('support') AND EXISTS (
     SELECT 1 FROM public.load_elite_assignments a
     JOIN public.user_elite_memberships m ON m.elite_id=a.elite_id
     JOIN public.elite_teams e ON e.id=a.elite_id
     WHERE a.load_id=p_load_id AND a.department='support'
       AND e.department='support' AND m.user_id=(SELECT auth.uid())
   ))
 );
$$;
REVOKE ALL ON FUNCTION public.can_see_load(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.can_see_load(uuid) TO authenticated;
DROP POLICY IF EXISTS loads_read ON public.loads;
CREATE POLICY loads_read ON public.loads FOR SELECT TO authenticated USING (public.can_see_load(id));
DROP POLICY IF EXISTS loads_update ON public.loads;
CREATE POLICY loads_update ON public.loads FOR UPDATE TO authenticated
 USING (public.can_see_load(id)) WITH CHECK (public.can_see_load(id));
DROP POLICY IF EXISTS assignments_read ON public.load_assignments;
CREATE POLICY assignments_read ON public.load_assignments FOR SELECT TO authenticated USING (public.can_see_load(load_id));
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
-- Prevent access to invoice rows for loads not visible (accounting currently globally authorized).
DROP POLICY IF EXISTS invoices_read ON public.invoices;
CREATE POLICY invoices_read ON public.invoices FOR SELECT TO authenticated USING (public.can_account() AND public.can_see_load(load_id));
-- Ensure no existing Support user without a membership is unintentionally locked out.
COMMIT;
