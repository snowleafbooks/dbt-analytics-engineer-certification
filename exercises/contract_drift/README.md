# Contract drift

**Error layer:** run (pre-DDL contract validation).
**Fix:** align the SQL projection with the YAML `columns:` list — either rename `status_label` back to `status` in the SQL, or update the YAML to declare `status_label`.

dbt runs the contract preflight before emitting any DDL, so no partial write ever hits the warehouse.
