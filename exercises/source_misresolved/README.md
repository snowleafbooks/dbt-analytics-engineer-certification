# Mis-pointed `source()`

**Trigger:** `dbt run --select stg_orders_misresolved` · **exit 1** · **layer: run**

**Expected error**

```
Failure in model stg_orders_misresolved (models/_tmp_broken/stg_orders_misresolved.sql)
  Database Error in model stg_orders_misresolved (models/_tmp_broken/stg_orders_misresolved.sql)
  relation "ecom_landing.orders" does not exist
  LINE 12: from "dbtae"."ecom_landing"."orders"
```

**Fix:** declare the schema the rows are actually in.

```yaml
sources:
  - name: ecom_landing
    schema: raw_ecom          # <- the missing line
    tables:
      - name: orders
```

## Diagnosing it

`dbt parse` exits 0. `dbt compile` exits 0. dbt never checks that a source exists — a source
is a *declaration* about the warehouse, taken at face value until a query is actually sent.
So triage runs the same three steps as any other "relation does not exist":

1. **Read the compiled SQL, not the model.** Run `dbt compile --select
   stg_orders_misresolved` and open `target/compiled/.../stg_orders_misresolved.sql`. It says
   `from "dbtae"."ecom_landing"."orders"`. That three-part name is the whole diagnosis: the
   model asked for something, and this is what dbt resolved it to.
2. **Check each part against the warehouse.** Database `dbtae` — correct. Schema
   `ecom_landing` — no such schema. Table `orders` — exists, but in `raw_ecom`.
3. **Fix the source declaration, never the model.** Nothing is wrong with
   `stg_orders_misresolved.sql`. Hard-coding a table name into it would remove the `source()`
   call and with it the lineage edge, the freshness check, and the source-level tests.

## Where the three parts come from

A `source()` resolves to `<database>.<schema>.<identifier>`, and each part has a default that
is easy to accept by accident:

| Property | Default when omitted | What it should be here |
|---|---|---|
| `database` | the target's database | `dbtae` — default is correct |
| `schema` | **the source's `name`** | `raw_ecom` — the default is what broke this |
| `identifier` | **the table's `name`** | `orders` — default is correct |

The middle row is the trap. Omitting `schema:` does not mean "leave it unset"; it means "use
the source name as the schema" — and a source name is chosen for how it reads inside
`source('...')` calls, not for where the data lives. `models/sources.yml` sets all three
deliberately: it declares a table as `product_catalog` with `identifier: products`, so
`source('raw_ecom', 'product_catalog')` reaches `raw_ecom.products`.

**The point:** source failures arrive late and warehouse-shaped, so they read like a data
problem and are almost always a YAML problem. If `dbt source freshness` passes on a source
whose models cannot find their table, you have proved the rows are arriving and the
resolution is wrong — two different questions, and only the second one is answered by
`database` / `schema` / `identifier`.
