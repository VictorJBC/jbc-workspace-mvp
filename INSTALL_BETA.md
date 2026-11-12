# JBC Workbench Beta — Frontend patch (11-12 base)

This is a **beta-only frontend entrypoint** for the new `jbc-workbench-beta` database. It intentionally replaces `index.html` with a focused Workbench UI. The legacy implementation is retained as `index.legacy.html`; original `src/*.js` modules are untouched.

## Apply

1. Back up or commit your current project. Extract this patch at project root, preserving directories.
2. In Supabase **jbc-workbench-beta** > SQL Editor, run `supabase/beta_migrations/002_live_queue_leadership_read.sql` once. **Do not run this in the old `jbc-workspace-mvp` project.** The original 001 migration must already have run.
3. Verify `.env.local` points to `jbc-workbench-beta`, with `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. Do not commit secrets or `.env.local`.
4. `npm install`, then `npm run dev`. Test all seven accounts; after testing, `npm run build`.
5. Do not deploy publicly until the access tests below pass.

## Scope

- Login via Supabase Auth, roles via `user_roles`, groups via `my_visibility_groups()`.
- Side navigation: Workbench, Live Queue (non-Support), Completed Tasks. Legacy modules preserved in repository, not mounted in beta.
- Task create/edit without load record, optional `shipment_number` text.
- STATUS classification and row color; separate execution status.
- VISIBILITY GROUP supports 4 Ops and 4 Support teams based on user memberships; Admin sees all.
- Live Queue read-only, due dates ascending, null dates last. Completed excluded.
- Panel stays mounted when switching beta views; unsaved form values remain.
- Task rows update classification without full page rerender; other saves refresh list after successful write.

## Security semantics

The SQL policy allows Operations and Accounting to **read all tasks** (not just Live Queue) while write permissions remain limited to their memberships or unassigned tasks. Admin may read/write all. Support can read/write only own group; Support cannot see Live Queue. This matches the latest agreed leadership Live Queue behavior. If all-group read access should be limited only to Live Queue, use a server-side read-only RPC and a narrower base table SELECT policy instead.

**Important:** Existing SQL `tasks_update` checks the group before and after modification; group reassignment between two groups requires membership in both. Accounting has no memberships in the current test configuration and therefore edits only unassigned tasks.

## Test matrix

- Support1: sees Support1 only; cannot access Live Queue; cannot create/edit Ops or Support2 tasks (including API calls).
- Operations: sees all tasks in Live Queue; can edit Ops1-4 and unassigned; cannot edit Support tasks.
- Accounting: sees all in Live Queue; edits unassigned only.
- Admin: sees and edits all; can assign any group.
- Creating task with no shipment succeeds; empty title fails.
- Switching between Workbench and Completed Tasks preserves an open form and unsaved text.
- Refresh browser and log out behavior; read-only Live Queue has no write controls.

## Deploy after verification

`npm run build` produces `dist/`. Host it in an independent Nginx site on Lightsail, with HTTPS, and use `try_files $uri $uri/ /index.html;` in the site configuration. Existing services remain untouched.

## Git

`git add index.html index.legacy.html src/beta.js src/beta.css supabase/beta_migrations/002_live_queue_leadership_read.sql INSTALL_BETA.md`
`git commit -m "feat(beta): task-only workbench with role-scoped groups and read-only live queue"`
