# JBC Workspace MVP

Temporary internal workspace for Support, Operations and Accounting. **Prototype only — not production-ready.**

## Current state
- `index.html`: original complete v2.1 app, **unchanged**. Uses browser `localStorage` and demo client-side authentication.
- `legacy/`: exact original source files and patches; patches are **already embedded** in `index.html` and must not be loaded twice.
- `docs/`: original IT handoff.
- `supabase/migrations/`: reserved for database schema, RLS and migrations. **Supabase is NOT connected yet.**

## Requirements
Node.js 20.19+ or 22.12+ recommended; Git; VS Code.

## Local run (demo only)
```bash
npm install
npm run dev
```
Open the localhost URL printed by Vite. The app will use browser-local demo data; no server-side login or shared persistence exists yet.

## Production safety
**Do not publish/deploy this demo or use real JBC customer, carrier, employee, or financial data.** Demo credentials and browser-only role checks are insecure. Private GitHub does not make a deployed site safe.
Never commit `.env` or privileged Supabase keys. The `VITE_` prefix exposes values to the browser: only public project URL and publishable/anon key belong there, with correctly configured RLS.

## Roadmap
1. Confirm roles, group visibility, financial field restrictions, and sources of truth for all 3 departments.
2. Design Postgres schema and deny-by-default RLS policies.
3. Replace demo login with Supabase Auth and secure profile/role resolution.
4. Move loads/tasks/stops and accounting to server-side persistence; implement audit and conflict handling.
5. Test concurrent sessions and unauthorized access, import workflow, backups and recovery.
6. Pilot with synthetic data before approving real operations.
