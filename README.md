# Partial patch - Create shipment draft and field order

Replace `src/operationalCreate.js` with the supplied file, restart Vite if needed, and test.

- Moves PO / Reference to the left of Support Elite.
- Aligns Pickup name/address and Delivery name/address in the same row.
- Persists in-progress form data in sessionStorage when navigating between tabs, restoring it when returning to Create shipment.
- Clears draft only after successful load/stops/Elite creation.

This is an intentionally partial patch. It does NOT implement customer/carrier/location catalog import, autocomplete, or the complete original Details screen. Those require schema, authorization and mapping work. Do not mistake this patch for those features.

Suggested commit after verification:
`git add src/operationalCreate.js && git commit -m "fix(create): preserve draft and align shipment fields"`
