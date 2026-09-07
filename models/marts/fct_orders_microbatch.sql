{#
    Microbatch incremental strategy.

    dbt splits the run into independent batches of `batch_size`, starting at `begin`, and
    executes each one separately. Note what is NOT here: no `is_incremental()` guard and no
    hand-written WHERE clause. dbt filters `ref('stg_orders')` for each batch automatically,
    using the `event_time` declared on that upstream model.

    `lookback=1` re-processes the previous batch as well as the current one, so late-arriving
    rows are picked up without a full refresh.

    Because each batch is a separate statement, a failure is retryable per batch rather than
    for the whole model -- inspect `target/run_results.json` after an interrupted run.

    `begin` reads `var('start_date')` from dbt_project.yml, which is the first business date
    the fixture covers (see data-seed/GENERATED.md); there is no point asking dbt to build
    empty batches before the fixture starts, and re-anchoring the fixture then only means
    editing one var. Note the other end: batches run from `begin` to the end of the current
    BATCH PERIOD, not to the current instant. With `batch_size='month'` the last batch spans
    the whole current calendar month -- its predicate is
    `created_at >= <first of this month> and created_at < <first of next month>` -- so this
    model does carry the fixture's forward-dated orders, the scheduled and pre-ordered rows,
    for the rest of the current month. `fct_orders` cuts at the exact instant of the run and
    does not, and that gap is what `analyses/compare_fct_orders_versions.sql` measures.
    Orders dated beyond the current month wait for their own batch: re-run the model next
    month and a month of new batches appears without any change to the SQL.

    ADAPTER NOTE (verified against the installed adapter, not assumed):
    `postgres__get_incremental_microbatch_sql` dispatches to `get_incremental_merge_sql`, so
    dbt-postgres runs each batch as a **MERGE** -- which is why Postgres 15+ is required and
    why `unique_key` is mandatory here. Omit `unique_key` and dbt raises
    "dbt-postgres 'microbatch' requires a `unique_key` config"; the first batch still succeeds,
    because a full refresh creates the table without taking the incremental path. Adapters with
    native partition replacement (BigQuery, Databricks) replace the partition instead and do
    not need it.
#}
{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='order_created_at',
    begin=var('start_date'),
    batch_size='month',
    lookback=1,
    unique_key='order_id',
    tags=['microbatch']
) }}

select
    order_id,
    customer_id,
    status,
    currency,
    order_total,
    created_at as order_created_at
from {{ ref('stg_orders') }}
