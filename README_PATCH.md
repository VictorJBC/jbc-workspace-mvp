# JBC Supabase Live Patch v2.1

This package supersedes v2; do not install v2 first.

## Install

1. Back up your existing `index.html` and `src/liveWorkspace.js`.
2. Copy `index.html` to the project root and `src/liveWorkspace.js` to `src/`.
3. Keep `.env.local`, `src/auth.js`, and Supabase migrations unchanged.
4. Start Vite with `npm run dev` and hard-refresh the browser.

## Changes

- Includes Supabase Live v2 creation, stop creation, load status editing, and shared tasks.
- Adds permanent `#shipment/<local-id>` routes to the legacy localStorage Shipment Details view.
- Preserves `#live/<uuid>` routes for Supabase records.
- Restores legacy shipment details on browser tab return/reload, if the record exists in this browser and the session is authorized.
- Preserves query strings in the browser URL.

## Test

1. Support: open a legacy shipment from Shipments; verify URL becomes `#shipment/<id>`; switch tabs and return; refresh and verify details remain.
2. Support: verify financial figures remain hidden.
3. Operations: open Shared Workspace, create `DEMO-OPS-003` (only once), verify pickup and delivery stops.
4. Support and Accounting: verify new load is visible, and New Load is blocked.
5. Open a Supabase load and verify its URL stays `#live/<uuid>`.

## Limitations

Legacy shipment records still reside in localStorage and are not shared between devices. `#shipment/<id>` only works in a browser with the corresponding local record. The shared Supabase view uses `#live/<uuid>`.

The UI does not replace PostgreSQL authorization; RLS and column-specific write restrictions must be validated before production.
