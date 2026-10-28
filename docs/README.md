# JBC Workspace Patch v3 — Stage 2 (membership + secure visibility + short links)

Based on **Workbench Tool newest.zip**. This is an incremental patch, not the complete 7-feature MVP integration.

## Before applying

1. Back up your project and Supabase database. **Do not execute** the older `20261028_003_elite_access.sql`.
2. Verify the prior `20261028_003_elite_preparation.sql` succeeded (8 teams / 12 demo assignments).
3. The demo account `victor@jbclogisticsinc.com` is assigned **Elite Support 1 and 2**; `alice@jbclogisticsinc.com` is assigned **Elite Ops 1 and 2**. These are testing defaults, not confirmed production memberships.

## Install in order

1. Copy `src/liveWorkspace.js` into your project, replacing the existing file. No other UI files are changed. Run `npm run dev` and check Shared Workspace: links now use `#live/DEMO-OPS-001`, not UUID. Existing UUID links redirect to the short link.
2. Run `20261028_004_elite_memberships.sql` in Supabase SQL Editor. Expect 4 result rows (2 Victor, 2 Alice). If different, STOP and investigate account emails/roles.
3. **Do not automatically run 005.** Before activating, verify *every active Support user* has at least one membership and every load they should see has a Support Elite. Run this read-only preflight:

```sql
SELECT u.email, p.active, count(m.elite_id) AS memberships
FROM public.profiles p JOIN auth.users u ON u.id=p.id
JOIN public.user_roles r ON r.user_id=p.id AND r.role='support'
LEFT JOIN public.user_elite_memberships m ON m.user_id=p.id
GROUP BY u.email,p.active ORDER BY u.email;
```

4. If the preflight is correct, run `20261028_005_elite_rls_activation.sql` in SQL Editor. Then verify in separate authenticated browser sessions: Support sees only assigned Elite loads; Operations sees all loads (including `DEMO-OPS-003` without an assignment); Accounting sees all loads. Try directly opening a disallowed load number as Support and confirm it fails.

## Known limits

- The original Shipments / Workbench still uses its local demo state. **Only Shared Workspace** uses the new RLS-protected Supabase loads. Connecting the original UI and preserving its task color/status semantics is a later stage.
- RLS limits row visibility but existing broad UPDATE grants allow authorized staff to edit columns they should not edit. Column-level restrictions / secure RPCs are needed before production.
- Financial fields are still not safely exposed to Support, but do not treat the current frontend as production-ready.
- New-load creation and stop insertion are separate requests, so a failed stop insert can leave a partial load.
- This patch does not alter the six demo records' content or task color codes.
