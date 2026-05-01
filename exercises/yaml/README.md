# YAML failure catalogue

Each `*.yml.broken` file demonstrates a distinct YAML-layer error. Rename the suffix to `.yml` and move the file into `models/` (or temporarily un-ignore `exercises/`) to trigger.

| File | Defect | Expected error |
|---|---|---|
| `indent.yml.broken` | `columns:` key indented under the wrong parent (3 spaces where 4 expected) | YAML parser surfaces a mapping/sequence mismatch |
| `wrong_type.yml.broken` | `materialized: true` (boolean where string expected) | dbt raises `Compilation Error ... two schema.yml entries for the same resource named fct_orders` — because `fct_orders` is already described in the main `_marts__models.yml`. To see the boolean-vs-string error itself, rename the model in the broken file to one that isn't yet described. |
| `unknown_key.yml.broken` | `frobulate:` — unknown property on a model | dbt warns (or fails with `--warn-error`): "unknown key" |

YAML errors are the first triage layer: if `dbt parse` fails before any Jinja or SQL is compiled, the cause is almost always a YAML structural issue.
