# Wrong type for a config value

**Trigger:** `dbt parse` · **exit 2** · **layer: parse**

`materialized:` is given the boolean `true` where a string is required. Note the second file
in this directory: `wrong_type_model.sql` is a one-line stub whose only job is to give the
properties block a node to attach to. Without it, dbt emits
`Did not find matching node for patch with name 'wrong_type_model'` — a **warning**, exit 0 —
and never validates the config at all.

**Expected error**

```
Parsing Error
  at path ['materialized']: True is not of type 'string'
```

**Fix:** `materialized: table` (or `view`, `incremental`, `ephemeral`, …). Watch for the
unquoted `on`/`off`/`yes`/`no`/`true`/`false` family, which YAML turns into booleans before
dbt ever sees them; quote the value if you mean the word.

**The point:** two things, and the second is the more useful one.

1. dbt type-checks the values of properties it knows. The error is a JSON-path — `at path
   ['materialized']` — not a line number, so search for the *key*, not for a location.
2. An unattached properties block is only a warning. A YAML file describing a model that does
   not exist (renamed, deleted, or never written) is silently inert, which is why "I set the
   config and nothing happened" is so often a name mismatch rather than a config problem.
   Compare `yaml_unknown_key`, where the silence is total.
