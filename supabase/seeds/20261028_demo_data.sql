-- JBC Workspace MVP: six entirely fictional loads for a controlled showcase.
-- Run in Supabase SQL Editor (privileged editor), AFTER schema and security migrations.
-- Safe to re-run: existing demo records are not overwritten or duplicated.
-- DO NOT run against a production database without explicit approval.
BEGIN;

INSERT INTO public.loads (
  load_number, customer_name, carrier_name, driver_name, driver_phone,
  equipment, po_number, ops_status, tracking_status, current_location,
  pickup_at, delivery_at, elite_team, dispatcher, appointment_note
)
VALUES
  ('DEMO-OPS-001','Demo Solar Supply','Demo Blue Ridge Transport','Jordan Test','555-0101','Dry Van','DEMO-PO-101','Dispatched','Pending','Dallas, TX','2026-10-29 09:00:00-05','2026-10-30 15:00:00-04','Elite 1','Demo Dispatcher','New load awaiting pickup'),
  ('DEMO-OPS-002','Demo Paper Group','Demo Northstar Freight','Taylor Test','555-0102','Dry Van','DEMO-PO-102','En Route','Active','Little Rock, AR','2026-10-27 08:00:00-05','2026-10-29 14:00:00-04','Elite 2','Demo Dispatcher','Pickup complete; monitor delivery ETA'),
  ('DEMO-SUP-001','Demo Retail Partners','Demo Canyon Carriers','Alex Test','555-0103','Reefer','DEMO-PO-201','At Pickup','Active','Phoenix, AZ','2026-10-28 10:00:00-07','2026-10-30 12:00:00-07','Elite 1','Demo Dispatcher','Confirm arrival and pickup documents'),
  ('DEMO-SUP-002','Demo Food Distribution','Demo Summit Transport','Morgan Test','555-0104','Reefer','DEMO-PO-202','At Delivery','Needs Attention','San Diego, CA','2026-10-27 07:00:00-07','2026-10-28 16:00:00-07','Elite 3','Demo Dispatcher','Delivery exception: POD missing'),
  ('DEMO-ACC-001','Demo Manufacturing','Demo Westgate Logistics','Casey Test','555-0105','Flatbed','DEMO-PO-301','Delivered','Completed','Denver, CO','2026-10-23 08:00:00-06','2026-10-25 15:00:00-06','Elite 2','Demo Dispatcher','Partial customer and carrier payments'),
  ('DEMO-ACC-002','Demo Packaging','Demo Ironwood Freight','Riley Test','555-0106','Dry Van','DEMO-PO-302','Delivered','Completed','Kansas City, MO','2026-10-21 09:00:00-05','2026-10-23 13:00:00-05','Elite 4','Demo Dispatcher','Customer invoice fully paid')
ON CONFLICT (load_number) DO NOTHING;

-- Each load has one pickup and one delivery. The UUIDs are stable on re-runs.
WITH demo_stops(load_number, stop_order, stop_type, name, address, appointment_at, status, arrived_at, completed_at) AS (
  VALUES
  ('DEMO-OPS-001',1,'Pickup','Demo Dallas Warehouse','Dallas, TX','2026-10-29 09:00:00-05'::timestamptz,'Pending',NULL::timestamptz,NULL::timestamptz),
  ('DEMO-OPS-001',2,'Delivery','Demo Atlanta DC','Atlanta, GA','2026-10-30 15:00:00-04'::timestamptz,'Pending',NULL,NULL),
  ('DEMO-OPS-002',1,'Pickup','Demo Houston Plant','Houston, TX','2026-10-27 08:00:00-05'::timestamptz,'Completed','2026-10-27 07:45:00-05'::timestamptz,'2026-10-27 09:10:00-05'::timestamptz),
  ('DEMO-OPS-002',2,'Delivery','Demo Nashville DC','Nashville, TN','2026-10-29 14:00:00-04'::timestamptz,'Pending',NULL,NULL),
  ('DEMO-SUP-001',1,'Pickup','Demo Phoenix Shipper','Phoenix, AZ','2026-10-28 10:00:00-07'::timestamptz,'At Pickup','2026-10-28 09:50:00-07'::timestamptz,NULL),
  ('DEMO-SUP-001',2,'Delivery','Demo Tucson Receiver','Tucson, AZ','2026-10-30 12:00:00-07'::timestamptz,'Pending',NULL,NULL),
  ('DEMO-SUP-002',1,'Pickup','Demo Los Angeles Shipper','Los Angeles, CA','2026-10-27 07:00:00-07'::timestamptz,'Completed','2026-10-27 06:45:00-07'::timestamptz,'2026-10-27 08:00:00-07'::timestamptz),
  ('DEMO-SUP-002',2,'Delivery','Demo San Diego Receiver','San Diego, CA','2026-10-28 16:00:00-07'::timestamptz,'At Delivery','2026-10-28 15:40:00-07'::timestamptz,NULL),
  ('DEMO-ACC-001',1,'Pickup','Demo Wichita Plant','Wichita, KS','2026-10-23 08:00:00-06'::timestamptz,'Completed','2026-10-23 07:55:00-06'::timestamptz,'2026-10-23 09:00:00-06'::timestamptz),
  ('DEMO-ACC-001',2,'Delivery','Demo Denver DC','Denver, CO','2026-10-25 15:00:00-06'::timestamptz,'Completed','2026-10-25 14:40:00-06'::timestamptz,'2026-10-25 15:30:00-06'::timestamptz),
  ('DEMO-ACC-002',1,'Pickup','Demo St Louis Plant','St. Louis, MO','2026-10-21 09:00:00-05'::timestamptz,'Completed','2026-10-21 08:50:00-05'::timestamptz,'2026-10-21 10:00:00-05'::timestamptz),
  ('DEMO-ACC-002',2,'Delivery','Demo Kansas City DC','Kansas City, MO','2026-10-23 13:00:00-05'::timestamptz,'Completed','2026-10-23 12:40:00-05'::timestamptz,'2026-10-23 13:30:00-05'::timestamptz)
)
INSERT INTO public.stops (id,load_id,stop_order,stop_type,name,address,appointment_at,status,arrived_at,completed_at)
SELECT md5('jbc-demo-stop:'||s.load_number||':'||s.stop_order)::uuid,l.id,s.stop_order,s.stop_type,s.name,s.address,s.appointment_at,s.status,s.arrived_at,s.completed_at
FROM demo_stops s JOIN public.loads l USING (load_number)
ON CONFLICT (id) DO NOTHING;

WITH demo_tasks(load_number, code, title, description, status, due_at) AS (
 VALUES
 ('DEMO-OPS-001','dispatch','Confirm carrier dispatch','Verify carrier assignment and pickup details','Open','2026-10-29 08:00:00-05'::timestamptz),
 ('DEMO-OPS-002','eta','Confirm delivery ETA','Request current ETA from driver','In Progress','2026-10-28 14:00:00-05'::timestamptz),
 ('DEMO-SUP-001','pickup','Confirm pickup arrival','Verify arrival and update pickup status','Open','2026-10-28 11:00:00-07'::timestamptz),
 ('DEMO-SUP-001','bol','Request signed BOL','Collect signed bill of lading after pickup','Open','2026-10-28 16:00:00-07'::timestamptz),
 ('DEMO-SUP-002','pod','Collect missing POD','Carrier has not supplied proof of delivery','Blocked','2026-10-28 18:00:00-07'::timestamptz),
 ('DEMO-SUP-002','receiver','Confirm receiver unload','Follow up on delivery exception','In Progress','2026-10-28 17:00:00-07'::timestamptz),
 ('DEMO-ACC-001','balance','Follow up on outstanding balances','Review remaining customer and carrier balances','Open','2026-11-02 12:00:00-06'::timestamptz),
 ('DEMO-ACC-002','reconcile','Reconcile customer payment','Verify customer invoice is fully settled','Completed','2026-10-27 12:00:00-05'::timestamptz)
)
INSERT INTO public.tasks(id,load_id,title,description,status,due_at,completed_at)
SELECT md5('jbc-demo-task:'||t.load_number||':'||t.code)::uuid,l.id,t.title,t.description,t.status,t.due_at,
       CASE WHEN t.status='Completed' THEN '2026-10-27 13:00:00-05'::timestamptz ELSE NULL END
FROM demo_tasks t JOIN public.loads l USING (load_number)
ON CONFLICT (id) DO NOTHING;

WITH demo_notes(load_number, code, body) AS (
 VALUES
 ('DEMO-OPS-002','progress','Fictional tracking note: driver confirmed pickup and is in transit.'),
 ('DEMO-SUP-001','pickup','Fictional support note: waiting for signed pickup documents.'),
 ('DEMO-SUP-002','exception','Fictional exception: POD requested from carrier; do not mark resolved yet.'),
 ('DEMO-ACC-001','accounting','Fictional accounting note: customer and carrier invoices have outstanding balances.')
)
INSERT INTO public.load_notes(id,load_id,body)
SELECT md5('jbc-demo-note:'||n.load_number||':'||n.code)::uuid,l.id,n.body
FROM demo_notes n JOIN public.loads l USING (load_number)
ON CONFLICT (id) DO NOTHING;

-- Two customer invoices and two carrier invoices; both sides have independent balances.
WITH demo_invoices(load_number, invoice_side, invoice_number, counterparty_name, total_amount, billing_status, issued_at, due_at) AS (
 VALUES
 ('DEMO-ACC-001','customer','DEMO-CUST-301','Demo Manufacturing',2500.00,'Processing','2026-10-26'::date,'2026-11-25'::date),
 ('DEMO-ACC-001','carrier','DEMO-CARR-301','Demo Westgate Logistics',1750.00,'Processing','2026-10-26'::date,'2026-11-09'::date),
 ('DEMO-ACC-002','customer','DEMO-CUST-302','Demo Packaging',1900.00,'Completed','2026-10-24'::date,'2026-11-23'::date),
 ('DEMO-ACC-002','carrier','DEMO-CARR-302','Demo Ironwood Freight',1250.00,'Ready for Billing','2026-10-24'::date,'2026-11-07'::date)
)
INSERT INTO public.invoices(id,load_id,invoice_side,invoice_number,counterparty_name,total_amount,billing_status,issued_at,due_at)
SELECT md5('jbc-demo-invoice:'||i.invoice_number)::uuid,l.id,i.invoice_side,i.invoice_number,i.counterparty_name,i.total_amount,i.billing_status,i.issued_at,i.due_at
FROM demo_invoices i JOIN public.loads l USING (load_number)
ON CONFLICT (id) DO NOTHING;

-- paid_on = effective payment date; paid_at = exact time (when known).
-- request_id is unique to each payment, preventing duplicate inserts on rerun.
WITH demo_payments(invoice_number, code, amount, paid_on, paid_at, reference, notes) AS (
 VALUES
 ('DEMO-CUST-301','partial1',1000.00,'2026-10-27'::date,'2026-10-27 11:30:00-05'::timestamptz,'DEMO-ACH-301-A','First partial customer payment'),
 ('DEMO-CARR-301','partial1',700.00,'2026-10-27'::date,'2026-10-27 15:00:00-05'::timestamptz,'DEMO-ACH-301-B','First partial carrier payment'),
 ('DEMO-CUST-302','final',1900.00,'2026-10-27'::date,'2026-10-27 10:15:00-05'::timestamptz,'DEMO-ACH-302','Full customer payment')
)
INSERT INTO public.invoice_payments(id,invoice_id,amount,paid_on,paid_at,reference,notes,request_id)
SELECT md5('jbc-demo-payment:'||p.invoice_number||':'||p.code)::uuid,
       i.id,p.amount,p.paid_on,p.paid_at,p.reference,p.notes,
       md5('jbc-demo-request:'||p.invoice_number||':'||p.code)::uuid
FROM demo_payments p JOIN public.invoices i USING (invoice_number)
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- Verification (privileged SQL Editor; not a user-level RLS test):
SELECT l.load_number,l.ops_status,
  (SELECT count(*) FROM public.stops s WHERE s.load_id=l.id) AS stops,
  (SELECT count(*) FROM public.tasks t WHERE t.load_id=l.id) AS tasks,
  (SELECT count(*) FROM public.invoices i WHERE i.load_id=l.id) AS invoices
FROM public.loads l WHERE l.load_number LIKE 'DEMO-%'
ORDER BY l.load_number;

-- Financial verification (SQL Editor only):
SELECT l.load_number, b.invoice_side, b.invoice_number, b.total_amount,
       b.amount_paid, b.balance_due, b.is_paid, b.fully_paid_on
FROM public.invoice_balances b JOIN public.loads l ON l.id=b.load_id
WHERE l.load_number IN ('DEMO-ACC-001','DEMO-ACC-002')
ORDER BY l.load_number,b.invoice_side;
