# Contract drift

**Trigger:** `dbt run --select contract_drift` · **exit 1** · **layer: run**

Exit **1**, not 2: the command itself ran fine, one node inside it failed. `dbt parse` and
`dbt compile` both exit 0 — a contract is checked against the *shape of the result set*,
which does not exist until dbt is about to build the model.

The YAML declares `(order_id, status)`. The SQL projects `(order_id, status_label)`.

**Expected error**

```
Failure in model contract_drift (models/_tmp_broken/contract_drift.sql)
  Compilation Error in model contract_drift (models/_tmp_broken/contract_drift.sql)
  This model has an enforced contract that failed.
  Please ensure the name, data_type, and number of columns in your contract match the columns in your model's definition.

  | column_name  | definition_type | contract_type | mismatch_reason       |
  | ------------ | --------------- | ------------- | --------------------- |
  | status       |                 | TEXT          | missing in definition |
  | status_label | TEXT            |               | missing in contract   |
```

**Fix:** align the two. Either rename `status_label` back to `status` in the SQL, or declare
`status_label` in the YAML `columns:` list.

**The point:** read the table, not the prose. Two rows — one `missing in definition`, one
`missing in contract` — with near-identical names is a rename; a single row is an added or
dropped column; a row with both type columns filled in is a type mismatch. And note what did
*not* happen: the preflight runs before any DDL is emitted, so nothing partial reaches the
warehouse. Check for yourself after the run:

```sql
select table_schema, table_name from information_schema.tables where table_name = 'contract_drift';
-- (0 rows)
```
