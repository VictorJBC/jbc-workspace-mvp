-- Patch v3 stage 2A: membership setup, NO changes to existing access policies.
-- Apply after 20261028_003_elite_preparation.sql.
BEGIN;
-- Demo accounts only; add/modify memberships later through admin-approved SQL.
INSERT INTO public.user_elite_memberships(user_id,elite_id)
SELECT p.id, e.id
FROM auth.users u
JOIN public.profiles p ON p.id=u.id
JOIN public.user_roles r ON r.user_id=p.id AND r.role='support'
JOIN public.elite_teams e ON e.department='support' AND e.team_number IN (1,2)
WHERE lower(u.email)='victor@jbclogisticsinc.com'
ON CONFLICT DO NOTHING;
-- Operations currently has global visibility, but membership is stored for assignment workflows.
INSERT INTO public.user_elite_memberships(user_id,elite_id)
SELECT p.id, e.id
FROM auth.users u
JOIN public.profiles p ON p.id=u.id
JOIN public.user_roles r ON r.user_id=p.id AND r.role='operations'
JOIN public.elite_teams e ON e.department='operations' AND e.team_number IN (1,2)
WHERE lower(u.email)='alice@jbclogisticsinc.com'
ON CONFLICT DO NOTHING;
COMMIT;
-- Verify: expect 2 memberships for each of the two demo accounts (if present and active).
SELECT u.email,e.name,e.department
FROM public.user_elite_memberships m
JOIN auth.users u ON u.id=m.user_id
JOIN public.elite_teams e ON e.id=m.elite_id
WHERE lower(u.email) IN ('victor@jbclogisticsinc.com','alice@jbclogisticsinc.com')
ORDER BY u.email,e.name;
