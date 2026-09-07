# A `ref()` inside a branch that was not taken

**Trigger:** `dbt parse`, twice · **exit 0 both times** · **no error, and two different graphs**

One file, two `ref()` calls, one `{% if %}`:

```sql
{% if var('use_products', false) %}
select product_id as id from {{ ref('stg_products') }}
{% else %}
select order_id as id from {{ ref('stg_orders') }}
{% endif %}
```

Dependencies are collected from the `ref()` calls that **execute** while dbt renders the file.
Jinja evaluates the `{% if %}` during that render, so exactly one branch is rendered and exactly
one `ref()` runs. The other one is text dbt never looked at.

```
$ dbt parse
  conditional_ref -> ['stg_orders']

$ dbt parse --vars '{use_products: true}'
  conditional_ref -> ['stg_products']
```

Same file, same commit, two different parents — and no error, no warning, nothing in the log.
The graph is a function of the context the file was parsed in.

## Why this is worse than a missing edge

`hardcoded_relation` gives you a model with no parents, which looks obviously wrong in a lineage
graph. This gives you a model with **one plausible parent**, which looks right. Everything that
reads the manifest — `dbt run --select +conditional_ref`, `state:modified+`, slim CI, the docs
site, an ownership audit — believes it.

The failure that follows is the classic one: CI parses with the default vars, decides
`stg_products` is not upstream of anything that changed, skips it, and the run reads a
`stg_products` that nobody rebuilt. Everything is green and the numbers are stale.

The same trap has a nastier form, because the branch condition is not always a `var()`:

- `{% if target.name == 'prod' %}` — dev and prod have different DAGs.
- `{% if is_incremental() %}` — the incremental branch is **not** rendered on a full refresh, so
  a `ref()` that only appears there can be absent from the graph.
- `{% if execute %}` — the guard people copy from the docs to make a `run_query` safe at parse
  time. `execute` is `False` during parsing, so a `ref()` inside that guard is never recorded.

## What to do instead

Put every `ref()` the model can ever read on an unconditional line, and branch only over what
you select from it:

```sql
-- depends_on: {{ ref('stg_products') }}
-- depends_on: {{ ref('stg_orders') }}
{% if var('use_products', false) %}
...
```

That is precisely the job `depends_on_comment` exists to do. And check the answer rather than
assuming it: `dbt ls --select +conditional_ref` prints the parents dbt actually recorded, under
the flags you actually ran.

**Related:** `depends_on_comment` (the repair), `hardcoded_relation` (no edge at all).
