# `ref()` typo

**Trigger:** `dbt parse` · **exit 2** · **layer: parse**

**Expected error**

```
Compilation Error
  Model 'model.dbtae_companion.ref_typo' (models/_tmp_broken/ref_typo.sql) depends on a node named 'stg_orderz' which was not found
```

**Fix:** `ref('stg_orderz')` → `ref('stg_orders')`. The **which was not found** clause names
the exact string dbt could not resolve, so the typo is in the error itself.

**The point:** this is the baseline shape of every unresolved-dependency error. Read the next
two exercises against it — `ref_disabled` and `ref_bad_version` are the same sentence with a
different final clause, and that clause is the whole diagnosis.
