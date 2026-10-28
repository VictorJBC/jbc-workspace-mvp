-- Stage 3A.3: authorized, read-only Elite lookup for Shipment Details.
-- Does not grant SELECT on membership or assignment tables.
BEGIN;
CREATE OR REPLACE FUNCTION public.get_visible_load_elites(p_load_id uuid)
RETURNS TABLE(department text, elite_name text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT a.department, e.name::text AS elite_name
  FROM public.load_elite_assignments AS a
  JOIN public.elite_teams AS e ON e.id = a.elite_id
  WHERE a.load_id = p_load_id
    AND (SELECT auth.uid()) IS NOT NULL
    AND public.can_see_load(p_load_id)
  ORDER BY a.department
$function$;
REVOKE ALL ON FUNCTION public.get_visible_load_elites(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_visible_load_elites(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_visible_load_elites(uuid) TO authenticated;
COMMIT;
-- Verify in SQL Editor:
-- SELECT proname, prosecdef FROM pg_proc WHERE oid = 'public.get_visible_load_elites(uuid)'::regprocedure;
-- SELECT grantee, privilege_type FROM information_schema.routine_privileges
-- WHERE routine_schema='public' AND routine_name='get_visible_load_elites';
