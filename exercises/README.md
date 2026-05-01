# Triage exercises

This directory holds deliberately-broken dbt examples. The whole tree is excluded from the project via `.dbtignore`, so the happy-path `dbt parse` / `dbt build` stays green.

## How to trigger an exercise

Each sub-directory is self-contained. To reproduce the error:

1. Read the sub-directory's `README.md`.
2. Either:
   - Copy the broken `.sql` file into `models/_tmp_broken/` (create the directory if needed).
   - Or rename a `.broken` file to `.sql` / `.yml` in place, and temporarily remove `exercises/` from `.dbtignore`.
3. Run the command listed in the sub-README (usually `dbt parse` or `dbt compile --select <model>`).
4. Observe the error. Compare against the expected error shape in the sub-README.
5. Clean up: `dbt clean`, restore `.dbtignore`, delete `models/_tmp_broken/`.

## Catalogue

| Directory | Error layer | Trigger command | Expected error shape |
|---|---|---|---|
| `cyclic/` | parse (DAG ordering) | `dbt compile` after copy to models/ | `Found a cycle: model.dbtae_companion.A --> model.dbtae_companion.B --> model.dbtae_companion.A` — dbt detects cycles during topological sort, not during manifest build, so `dbt parse` passes cleanly but any command that needs execution order (`compile`/`run`/`build`) surfaces it |
| `ref_typo/` | parse | `dbt parse` | `Compilation Error ... depends on a node named 'stg_orderz' which was not found` |
| `ref_disabled/` | parse | `dbt parse` | `references a node which is disabled` |
| `ref_bad_version/` | parse | `dbt parse` | `references a version (v=99) of a model that does not exist` |
| `contract_drift/` | run | `dbt run --select contract_drift` | `Compilation Error ... columns in your `yml` file ... do not match the columns in your SQL file` |
| `access_violation/` | parse | `dbt parse` | `DbtReferenceError ... access is set to private and is in group 'pii'` |
| `public_ephemeral/` | parse | `dbt parse` | `InvalidAccessError ... ephemeral models cannot be marked as 'access: public'` |
| `macro_undefined/` | compile | `dbt compile --select macro_undefined` | `Compilation Error ... 'generate_surrogate_key' is undefined` (missing `dbt_utils.` prefix) |
| `macro_arity/` | compile | `dbt compile --select macro_arity` | `cents_to_dollars() got an unexpected keyword argument 'precision_level'` |
| `dispatch_miss/` | compile | `dbt compile --select dispatch_miss` | `In dispatch: No macro named 'default__i_am_not_implemented' found` |
| `jinja_unbalanced/` | parse | `dbt parse` | `Unexpected end of template. Jinja was looking for 'endif'` |
| `yaml/` | parse | rename `.broken` → `.yml`, `dbt parse` | `YAML parse error` (varies by case) |

## Why gate via `.dbtignore` instead of `enabled: false`?

Several of these errors fire at parse time (cyclic refs, Jinja syntax errors, YAML structure, access/ephemeral validation). The `enabled: false` config kicks in AFTER parse, so it can't protect the project from parse-fatal files. Ignoring the directory wholesale is the only reliable guard.
