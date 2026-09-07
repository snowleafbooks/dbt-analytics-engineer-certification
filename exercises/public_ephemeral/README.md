# `access: public` + `materialized: ephemeral`

**Trigger:** `dbt parse` · **exit 2** · **layer: parse**

**Expected error**

```
Parsing Error
  Node model.dbtae_companion.public_ephemeral with 'ephemeral' materialization has an invalid value (public) for the access field
```

**Fix:** materialize it as `view` or `table`. (Or drop back to the default
`access: protected` if it really should stay ephemeral.)

**The point:** an ephemeral model has no warehouse identity — it is inlined as a CTE and
never lands as a relation. `access: public` is a promise that other projects may depend on
the model, and there would be nothing for them to depend on. dbt rejects the combination
outright rather than letting it fail later.
