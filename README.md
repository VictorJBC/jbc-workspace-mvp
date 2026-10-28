Patch v3 Stage 3A.1 - Shipments original UI restoration

Back up index.html and src/originalViews.js. Replace only src/originalViews.js with the file in this ZIP. Keep existing index.html, originalViewsBootstrap.js, and liveWorkspace.js (short URL hotfix). Restart Vite. No SQL.

Shipments: original v10 table layout, chips, badges, search, column selection, CSV export, checkboxes, pagination, sorting. Data from Supabase loads and stops; RLS applies. New shipment routes to Shared Workspace. Bulk updates intentionally disabled in read-only stage. Financial columns intentionally excluded pending secure finance access. Workbench and Shipment Details unchanged.

Test with Alice: seven loads, statuses, origin/destination, filters, click through. With Victor: six loads, no DEMO-OPS-003. No localStorage fallback.
