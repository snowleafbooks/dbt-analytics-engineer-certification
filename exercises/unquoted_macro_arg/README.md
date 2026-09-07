# Unquoted macro argument — read as a Jinja variable

**Trigger:** `dbt run --select unquoted_macro_arg` · **exit 1** · **layer: run**

One missing pair of quotes:

```sql
{{ cents_to_dollars(price_cents) }} as price_usd
```

`cents_to_dollars` wants the **name of a column**, as a string. Unquoted, `price_cents` is a
Jinja *variable* — and no variable by that name exists, so it resolves to Undefined, renders as
the empty string, and the macro builds its expression around nothing.

**`dbt parse` exits 0. `dbt compile` exits 0.** Both stay silent, and the compiled artifact is
where the damage first becomes visible:

```
$ dbt compile --select unquoted_macro_arg
$ tail -5 target/compiled/dbtae_companion/models/_tmp_broken/unquoted_macro_arg.sql
select
    
    round(cast( as numeric) / 100.0, 2)
 as price_usd
from "dbtae"."dev"."stg_products"
```

**Expected error**

```
Database Error in model unquoted_macro_arg (models/_tmp_broken/unquoted_macro_arg.sql)
  syntax error at or near "as"
  LINE 13:     round(cast( as numeric) / 100.0, 2)
                           ^
```

**Fix:** `cents_to_dollars('price_cents')`.

**The point:** the error arrives from Postgres, about a line number in generated SQL, quoting a
fragment (`cast( as numeric)`) that appears in no file you wrote. Neither `price_cents` nor
`cents_to_dollars` is named anywhere in it. The only way back to the cause is to read the
compiled file — the caret is pointing at a hole where an argument should be, and the hole is the
whole diagnosis.

**Why nothing is raised earlier.** dbt's Jinja environment renders an undefined name as an empty
string rather than raising. That is deliberate and load-bearing — plenty of legitimate templates
test names that may not be bound — but it means a typo'd or unquoted argument is not an error,
it is a value. Every layer downstream is working correctly on a string with a gap in it.

The same shape shows up wherever a macro takes a name:

- `{{ dbt_utils.star(from=ref('stg_orders'), except=[order_id]) }}` — `except` needs `['order_id']`.
- `{{ dbt_utils.generate_surrogate_key([order_id, customer_id]) }}` — quotes on both.
- `{{ config(materialized=table) }}` — silently `materialized=''`, so the model stays a **view**
  and nothing anywhere says so. This one does not even fail; see `yaml_unknown_key` for the
  same lesson in YAML.

**Related:** `macro_arity` is the adjacent case and it behaves the opposite way — a *known*
macro given a *wrong keyword name* is caught by Jinja at bind time and dies at **parse**, exit
2, naming both the macro and the bad argument. The difference is that a wrong kwarg name is a
signature violation, while an unquoted positional argument is a perfectly valid expression that
happens to evaluate to nothing. `macro_undefined` is the third member: an unknown macro *name*
survives parse and dies at compile.
