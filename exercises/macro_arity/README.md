# Macro called with the wrong keyword argument

**Trigger:** `dbt parse` · **exit 2** · **layer: parse**

`dbt compile --select macro_arity` reproduces it too, but `dbt parse` alone is enough — and
that is the interesting part.

**Expected error**

```
Compilation Error in model macro_arity (models/_tmp_broken/macro_arity.sql)
  macro 'dbt_macro__cents_to_dollars' takes no keyword argument 'precision_level'
```

**Fix:** `precision_level=4` → `precision=4`. The signature in
[`macros/cents_to_dollars.sql`](../../macros/cents_to_dollars.sql) is authoritative.

**The point:** the macro in the error is called `dbt_macro__cents_to_dollars`, not
`cents_to_dollars` — dbt namespaces every project macro with a `dbt_macro__` prefix
internally, so grepping the repo for the string in the error finds nothing. Strip the prefix
before you search. And note the layer: because `cents_to_dollars` *exists*, Jinja binds it
during the parse-time render and rejects the bad kwarg there. See `macro_undefined` for the
case that behaves the other way.
