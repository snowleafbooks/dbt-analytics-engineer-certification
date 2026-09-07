# `check` constraint on a column with no `data_type`

**Trigger:** `dbt run --select constraint_missing_data_type` · **exit 1** · **layer: run**

The YAML puts a `check` constraint on `price_cents` and never declares that column's
`data_type`. `dbt parse` and `dbt compile` both exit **0** — nothing is wrong with the YAML
as YAML, and nothing is wrong with the SQL. The defect surfaces only when dbt builds the
DDL, because a constraint is rendered as part of a column definition and there is no type to
render it onto.

**Expected error**

```
Failure in model constraint_missing_data_type (models/_tmp_broken/constraint_missing_data_type.sql)
  Compilation Error in model constraint_missing_data_type (models/_tmp_broken/constraint_missing_data_type.sql)
  Contracted models require data_type to be defined for each column. Please ensure that the column name and data_type are defined within the YAML configuration for the ['price_cents'] column(s).
```

**Fix: add the type. Do not remove the constraint.**

```yaml
      - name: price_cents
        data_type: integer          # <- the missing line
        constraints:
          - type: check
            expression: "price_cents >= 0"
```

**Deleting the `check` block does NOT make the error go away.** It is worth trying, because the
message names the *constraint's* column and reads as if the constraint were the problem. It is
not: under an enforced contract `data_type` is required on every declared column, constraint or
no constraint. Measured on dbt-core 1.11.14, 2026-09-06 — with the `constraints:` block removed
and `- name: price_cents` still there, the run returns the identical error and exit 1:

```
Contracted models require data_type to be defined for each column. Please ensure that the column name and data_type are defined within the YAML configuration for the ['price_cents'] column(s).
```

Deleting the whole `price_cents` entry does silence *that* message, and earns a different one —
which is the better lesson, because it shows the contract checking both directions:

```
This model has an enforced contract that failed.
| column_name | definition_type | contract_type | mismatch_reason     |
| price_cents | INTEGER         |               | missing in contract |
```

The only fix that builds is the one above: declare the type.

**The point:** under `contract: {enforced: true}`, `data_type` is not optional on any column
— it *is* the contract. Constraints are rendered into the `create table` statement alongside
the type, which is why a missing type takes the constraint down with it, and why the error
names the column list rather than the constraint. Contrast `contract_drift`: same layer, same
exit code, but that one is a mismatch between two stated shapes, while this one is a shape
that was never fully stated. `models/marts/dim_products.sql` and its YAML are the working
reference — every contracted column there declares a type.
