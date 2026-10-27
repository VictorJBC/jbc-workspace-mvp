# JBC Workspace v2.1 — Frontend / IT handoff

**Purpose:** A local interactive prototype for interim Support, Operations and Accounting workflows. **Not** the JBC corporate AI TMS, not a replacement for BrokerPro, and not production-ready. Never use real customer, carrier or financial data in this local demonstration without IT approval.

## Files
- `JBC_Workspace_v2_1_Operations_Accounting.html` — complete local prototype, retains original CSS, logo and sample data; incorporates the v2.1 additions.
- `jbc_v21_patch.js` — added frontend and workflow code; integrated into the complete HTML.
- `jbc_v21_patch.css` — added styling; integrated into the complete HTML.

## Demo credentials
- Senior/admin: **user / 123**
- Operations: **ops1@jbc.com**, **ops2@jbc.com**, **ops3@jbc.com**, **ops4@jbc.com** / **ops123**
- Existing Elite Support demo accounts remain in the prototype. These are **simulated client-side roles**, not real authentication. Password hashes and UI restrictions must not be relied on for security.

## Data structures added to each shipment

| Field | Type | Meaning |
| --- | --- | --- |
| `opsStatus` | string | One of Dispatched, At pickup, Picked up, En route, At delivery, Delivered, Route complete, On Hold |
| `billingStatus` | string | One of Ready for billing, Processing, Completed, Canceled |
| `stops[]` | array | Ordered shipper → intermediate stops → receiver; each `{type, name, address, appointment, done}` |
| `assignedGroups[]` | string[] | Elite Support 1–4, Elite Ops 1–4, Seniors, Accounting |
| `assignedUsers[]` | string[] | Additional assigned users (currently stored as names) |
| `owner` | string | Primary owner |
| `value`, `carrierPay`, `margin` | numbers | Bill, carrier pay and calculated gross margin |
| `milesOut`, `eta`, `location` | number/string | Currently manual values or demonstration values |
| `trackingUrl`, `trackingUpdatedAt` | string | External tracking reference and last verified timestamp |
| `brokerName`, `brokerContact`, `brokerPhone`, `dispatcher` | string | Operations contacts |
| `tasks[]`, `events[]`, `notes` | arrays/string | Existing history and task structure preserved |

Existing `pickup`, `delivery`, `pu`, and `del` fields mirror the first and last stops. The last-stop circle fills when delivery is completed; the first-stop circle fills after pickup. **Delivered** and **Route complete** are distinct states.

## Proposed backend endpoints (design suggestions; not implemented)

The backend should define and validate its own contract, preferably with versioned routes:

- `GET /api/v1/shipments?team=...&status=...` — return authorized loads, never trusting browser-provided group assignments.
- `GET /api/v1/shipments/{id}` — shipment + stops + tasks + documents + contacts, with financial field redaction by role.
- `POST /api/v1/shipments` — create a unique load; reject duplicate load numbers.
- `PATCH /api/v1/shipments/{id}` — update with optimistic locking (`version`, `updatedAt`) and change audit.
- `POST /api/v1/shipments/{id}/tasks` and `PATCH /api/v1/tasks/{id}` — tasks and due times.
- `GET /api/v1/shipments/{id}/tracking` — *server-side* Carrier View adapter; normalize `currentLocation`, `milesOut`, `eta`, `lastUpdate`, `source`, and stop milestones.
- `GET /api/v1/shipments/{id}/presence` and WebSocket/SSE stream — authorized active viewers and first/last view time, with heartbeat/expiry.
- `GET /api/v1/shipments/{id}/documents` etc. — server-backed attachments with access controls.
- BrokerPro adapter: separate read and write paths, field allowlists, audit, retry/backoff, idempotency, and a clearly identified source of truth.

Do **not** put BrokerPro or Carrier View API keys, secrets or service tokens in the HTML/JavaScript client. The demo `J21_API.carrierViewTrackingEndpoint` string is empty. It expects an approved JBC backend proxy which handles authentication, authorization and vendor API calls. The button intentionally reports "not configured" until IT configures it.

## What currently works locally

- Task-first Workbench with inline text, status markers, due times, search and side panel.
- Shipment header, stage, stop timeline, editable Details and accounting cards.
- Google Maps Directions opens a new tab with pickup, destination and ordered intermediate stop addresses. It does not verify the addresses against the provider.
- Operations Board creates draft loads, modifies operational status, opens Details.
- Accounting list can change billing status and view computed margin in the authorized senior demo account.
- Demo Ops accounts are scoped by Elite team in client-side code.
- Dates can be typed in `datetime-local` inputs or set with the browser picker.
- Planning ETA can be estimated from manually entered remaining miles and average speed, explicitly **not** a live carrier ETA.
- The current viewer display is **per browser only**, with recorded first/last local views; it is **not live presence**.

## What does NOT yet work as a real shared application

- No cloud database or concurrency control. Everything is `localStorage` scoped to one browser profile.
- No production login, role enforcement, financial authorization or audit backend.
- No BrokerPro data synchronization (current buttons are demo-only).
- No Carrier View live ETA, distance or position (backend connection unavailable).
- No true multiuser presence, push updates, secure file storage or automated backups.
- The map on the shipment header is a labelled schematic, not a live geographical map; Google Maps Directions is a separate external tab.
- No deployment, security review, staging data migration, or end-to-end multiuser acceptance tests.

## Recommended first IT validation

1. Confirm scope with Operations, Support and Accounting; identify the system of record for each data category.
2. Audit BrokerPro and Carrier View APIs/permissions. Test a single authorized read request first.
3. Choose JBC-approved AWS architecture, database and identity provider; establish development/staging environments.
4. Put the source in a private repo; modularize the single HTML progressively with a build process.
5. Implement one vertical slice: authenticate → load a task → edit and save → open from another authorized session → see the same update.
6. Add permissions and financial redaction **on the server**, concurrency handling, error feedback, logs, tests, and backups.
7. Implement stop/tracking events and billing workflow after data contracts are confirmed.
8. Pilot internally using synthetic data before any production rollout.

## Testing performed on the v2.1 prototype

Headless Chromium simulation using `page.set_content`, with browser storage stubbed because direct local/web navigation was restricted in the test environment:
- Demo user login / Workbench rendering.
- Operations Board navigation and search.
- Create a shipment; add a third stop; edit company, origin/destination, financial numbers; save; verify persisted in `db.loads` and gross margin calculation.
- Verify three-stop Google Maps URL generation.
- Navigate to Accounting with saved shipment.
- Edit an existing shipment, verify its previous tasks were preserved; distinguish Delivered from Route complete and remove completed routes from active Operations Board.
- Operations demo login with team scope.
- No runtime JavaScript errors in the above tested flows.

This is a UI integration check, not a security, load, multiuser, backend or provider API certification.
