# `ref()` with an invalid version

**Trigger:** `dbt parse` · **exit 2** · **layer: parse**

**Expected error**

```
Compilation Error
  Model 'model.dbtae_companion.ref_bad_version' (models/_tmp_broken/ref_bad_version.sql) depends on a node named 'dim_customer_segments' with version '99' which was not found
```

**Fix:** `v=99` → `v=1` or `v=2`, the two versions declared for `dim_customer_segments` in
`models/marts/_marts__models.yml`. Or drop `v=` entirely and take `latest_version`.

**The point:** the third variant of the unresolved-dependency sentence. The model name
resolves; the **version** does not, and the error says so with `with version '99'`. Chasing
the model name here wastes the search — the defect is in the `v=` argument.
