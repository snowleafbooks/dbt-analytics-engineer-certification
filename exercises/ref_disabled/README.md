# `ref()` to a disabled model

**Trigger:** `dbt parse` · **exit 2** · **layer: parse**

**Expected error**

```
Compilation Error
  Model 'model.dbtae_companion.consumer_of_disabled' (models/_tmp_broken/consumer_of_disabled.sql) depends on a node named 'disabled_target' which is disabled
```

**Fix:** either flip `disabled_target` to `enabled=true`, or drop the `ref()`.

**The point:** compare the final clause with `ref_typo`'s. **which is disabled** and
**which was not found** are different diagnoses with different fixes — the file is on disk
and the name is spelled right, so searching the repo for the name will find it and mislead
you. `enabled: false` takes a node out of the graph entirely; downstream refs then behave as
if it were never written.
