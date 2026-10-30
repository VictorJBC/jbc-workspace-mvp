-- JBC Stage 3B.2: task classification + authorized elite assignment.
-- Apply only after 006. No changes to existing RLS policies.
BEGIN;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS task_code text NOT NULL DEFAULT 'No status';
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS task_queue text NOT NULL DEFAULT 'Active Tasks';
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS task_elite_id uuid REFERENCES public.elite_teams(id) ON DELETE SET NULL;
ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_task_code_check;
ALTER TABLE public.tasks ADD CONSTRAINT tasks_task_code_check CHECK (task_code IN ('No status','LOADED?','LOCATION?','Not tracking','ARRIVED@DEL','DEL?','DELAYED','POD PENDING'));
ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_task_queue_check;
ALTER TABLE public.tasks ADD CONSTRAINT tasks_task_queue_check CHECK (task_queue IN ('Active Tasks','Seniors Only','Support POD Pending','Back to Ops'));
CREATE OR REPLACE FUNCTION public.set_load_elites(p_load_id uuid,p_support_elite_id uuid,p_operations_elite_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_dept text; v_id uuid;
BEGIN
 IF (SELECT auth.uid()) IS NULL OR NOT public.can_create_load() THEN RAISE EXCEPTION 'Not authorized'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.loads WHERE id=p_load_id) THEN RAISE EXCEPTION 'Load not found'; END IF;
 FOR v_dept,v_id IN SELECT * FROM (VALUES ('support',p_support_elite_id),('operations',p_operations_elite_id)) AS x(dept,elite_id)
 LOOP
   IF v_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.elite_teams WHERE id=v_id AND department=v_dept) THEN
     RAISE EXCEPTION 'Invalid Elite for %',v_dept;
   END IF;
   IF v_id IS NULL THEN
     DELETE FROM public.load_elite_assignments WHERE load_id=p_load_id AND department=v_dept;
   ELSE
     INSERT INTO public.load_elite_assignments(load_id,department,elite_id) VALUES(p_load_id,v_dept,v_id)
     ON CONFLICT (load_id,department) DO UPDATE SET elite_id=EXCLUDED.elite_id;
   END IF;
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.set_load_elites(uuid,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.set_load_elites(uuid,uuid,uuid) TO authenticated;
-- Expose only catalog IDs and names; memberships and assignments remain protected.
GRANT SELECT ON public.elite_teams TO authenticated;
DROP POLICY IF EXISTS elite_catalog_read ON public.elite_teams;
CREATE POLICY elite_catalog_read ON public.elite_teams FOR SELECT TO authenticated USING (public.is_staff());
COMMIT;
