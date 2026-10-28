-- JBC Workspace - Elite preparation (safe, no RLS changes)
-- Run after existing schema/security and demo seed. Idempotent for this patch.
-- Does not grant browser access to new tables or change existing load visibility.
BEGIN;

CREATE TABLE IF NOT EXISTS public.elite_teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department text NOT NULL CHECK (department IN ('support','operations')),
  team_number integer NOT NULL CHECK (team_number BETWEEN 1 AND 4),
  name text GENERATED ALWAYS AS (
    (CASE WHEN department = 'support' THEN 'Elite Support ' ELSE 'Elite Ops ' END) || team_number::text
  ) STORED,
  UNIQUE (department,team_number),
  UNIQUE (id,department)
);

CREATE TABLE IF NOT EXISTS public.user_elite_memberships (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  elite_id uuid NOT NULL REFERENCES public.elite_teams(id) ON DELETE CASCADE,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id,elite_id)
);

CREATE TABLE IF NOT EXISTS public.load_elite_assignments (
  load_id uuid NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
  department text NOT NULL CHECK (department IN ('support','operations')),
  elite_id uuid NOT NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (load_id,department),
  FOREIGN KEY (elite_id,department) REFERENCES public.elite_teams(id,department)
);

CREATE INDEX IF NOT EXISTS load_elite_assignments_elite_idx ON public.load_elite_assignments(elite_id,load_id);
CREATE INDEX IF NOT EXISTS user_elite_memberships_elite_idx ON public.user_elite_memberships(elite_id,user_id);

INSERT INTO public.elite_teams(department,team_number)
SELECT d.department, n
FROM (VALUES ('support'),('operations')) AS d(department)
CROSS JOIN generate_series(1,4) AS n
ON CONFLICT (department,team_number) DO NOTHING;

-- Assign each of the six demo loads to a Support and Operations Elite.
-- Demo values only: these are not real company routing rules.
WITH demo(load_number,support_number,operations_number) AS (
  VALUES
    ('DEMO-OPS-001',1,1),
    ('DEMO-OPS-002',2,2),
    ('DEMO-SUP-001',1,3),
    ('DEMO-SUP-002',2,4),
    ('DEMO-ACC-001',1,2),
    ('DEMO-ACC-002',2,1)
), proposed AS (
  SELECT l.id AS load_id, et.department, et.id AS elite_id
  FROM demo d
  JOIN public.loads l ON l.load_number = d.load_number
  JOIN public.elite_teams et ON
    (et.department='support' AND et.team_number=d.support_number)
    OR (et.department='operations' AND et.team_number=d.operations_number)
)
INSERT INTO public.load_elite_assignments(load_id,department,elite_id)
SELECT load_id,department,elite_id FROM proposed
ON CONFLICT (load_id,department) DO NOTHING;

-- Prepare RLS on new tables WITHOUT changing any existing policies.
-- No browser grants: tables remain inaccessible from client until security migration.
ALTER TABLE public.elite_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_elite_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.load_elite_assignments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.elite_teams, public.user_elite_memberships, public.load_elite_assignments FROM anon,authenticated;

COMMIT;

-- Read-only verification: expect 8 teams and 12 assignments if all 6 demo loads exist.
SELECT 'elite_teams' AS item, count(*) AS total FROM public.elite_teams
UNION ALL
SELECT 'demo_load_elite_assignments', count(*)
FROM public.load_elite_assignments a
JOIN public.loads l ON l.id=a.load_id
WHERE l.load_number IN ('DEMO-OPS-001','DEMO-OPS-002','DEMO-SUP-001','DEMO-SUP-002','DEMO-ACC-001','DEMO-ACC-002');
