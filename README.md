# JBC Workspace — Patch v3 Stage 3A.3: Elite Lookup Hotfix

Fixes `permission denied for table load_elite_assignments` on the restored Shipment Details screen, **without granting direct table access**.

## Install (in this order)

1. Make a recoverable Supabase backup and copy `src/originalViews.js` as a local backup.
2. Supabase > SQL Editor: run the entire `supabase/migrations/20261028_006_visible_load_elites_rpc.sql` file. It creates a read-only, SECURITY DEFINER function which checks `auth.uid()` and `can_see_load()` before returning Elite names. No existing RLS policies are replaced.
3. Replace **only** `src/originalViews.js` with the file in this ZIP. Preserve your current `index.html`, `src/liveWorkspace.js` (short URL hotfix), and `src/originalViewsBootstrap.js`.
4. Restart Vite (`npm run dev`), hard refresh.
5. As Alice (Operations), open `#shipment/DEMO-SUP-002`: the original layout should show and the Support/Ops Elite names should appear. As Victor (Support), test a load assigned to Support Elite 1 or 2; `#shipment/DEMO-OPS-003` must remain inaccessible. Verify Shared Workspace, Shipments and Workbench.

The Elite lookup is deliberately **noncritical**: if the RPC fails, the page renders its other authorized details and shows `Unavailable` for the Elite fields; check browser Console for a warning. It does **not** silently substitute local demo data. This stage remains read-only.

## Rollback

Restore the previous `src/originalViews.js` backup. To remove the RPC only if no frontend depends on it, execute `DROP FUNCTION IF EXISTS public.get_visible_load_elites(uuid);` in SQL Editor. Note that the old frontend will again fail on the restricted table, so normally keep the RPC and fix frontend instead.

## Commit (only after tests pass)

```powershell
git add src/originalViews.js supabase/migrations/20261028_006_visible_load_elites_rpc.sql
git commit -m "fix(shipment-details): fetch elite assignments through authorized RPC"
git push origin main
```

Copy the SQL migration into your local project's `supabase/migrations/` folder before running git add.
