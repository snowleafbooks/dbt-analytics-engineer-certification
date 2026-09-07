# Undefined macro (missing package namespace)

**Trigger:** `dbt compile --select macro_undefined` · **exit 2** · **layer: compile**

**Expected error**

```
Runtime Error
  Compilation Error in model macro_undefined (models/_tmp_broken/macro_undefined.sql)
    'generate_surrogate_key' is undefined. This can happen when calling a macro that does not exist. Check for typos and/or install package dependencies with "dbt deps".
```

**Fix:** `{{ dbt_utils.generate_surrogate_key(['customer_id']) }}` — the macro lives in the
`dbt_utils` namespace and needs the prefix.

**The point — and the reason to run this next to `macro_arity`:** `dbt parse` on this fixture
exits **0**. An unknown *name* renders to a Jinja `Undefined` object at parse time and only
detonates when something tries to call it, which is the compile step. Contrast `macro_arity`
and `dispatch_miss`: a *known* macro called wrongly raises during the parse-time render, one
layer earlier. "It is a macro error" does not tell you which command will surface it.
