{# Incremental merge strategy (dbt-postgres native MERGE, which needs Postgres 15+).
   Composite unique_key; grants merge via '+select'.

   `on_schema_change='fail'` is not a free choice here: dbt refuses an incremental model that
   is contracted AND set to 'sync_all_columns' or 'ignore' -- "Models materialized as
   incremental with contracts enabled must set on_schema_change to 'append_new_columns' or
   'fail'". That refusal is the right one. A contract is a promise about this relation's
   shape; a mode that silently reshapes the table to match whatever the SQL now returns is
   the opposite of a promise. `sync_all_columns` is demonstrated on fct_audit_events instead.

   Contracted -- see _marts__models.yml for the typed columns. The project's `foreign_key`
   constraint is on fct_segment_activity, not here, and the YAML explains why: dbt drops a
   table model with `drop table ... cascade`, so rebuilding dim_products would drop any FK
   aimed at it, and an incremental model is not recreated afterwards to get it back.

   The future-order rule is applied here as well as in fct_orders. A line item is not a
   fact until its order is one, so the two marts share a single cut-off expression; if
   only fct_orders filtered, a scheduled order's lines would sit in the mart with no
   parent row to join to.

   `merge_exclude_columns=['loaded_at']` narrows what a MATCHED row updates. By default a
   merge overwrites every column of a matched row from the source; with this set, dbt builds
   the `update set` clause from every column EXCEPT the ones named, so the value already in
   the table survives. That is the documented way to keep a first-seen timestamp: `loaded_at`
   here records when the line first landed in the warehouse, and re-merging the same line
   must not reset it to the current load. `merge_update_columns` is the same lever inverted
   -- an allowlist instead of a denylist -- and the two are mutually exclusive.

   It is visible in the compiled merge, and only there, because dbt writes the column list
   into the DDL rather than passing a flag to the warehouse:

     dbt run --select fct_order_items
     grep -A 30 'merge into' target/run/dbtae_companion/models/marts/fct_order_items.sql

   The `when matched then update set` block names the other fourteen columns and not
   `loaded_at`; `when not matched then insert` still names all fifteen, because an inserted
   row has no previous value to preserve.

   Measured against the warehouse, and it holds. Order 1 line 1 sat at
   loaded_at = 2025-01-13 14:18:38. Change the LINE's `loaded_at` at source to now(), push
   the parent ORDER's `updated_at` past the watermark, re-run: `MERGE 1`, the row's
   `order_updated_at` moves to the new value -- so it really was updated -- and `loaded_at`
   is still 2025-01-13 14:18:38. Without the config it would have followed the source.

   One trap if you reproduce it. The predicate below takes a GLOBAL max of
   `order_updated_at`, and this fixture carries orders dated well into the future, so the
   watermark sits ahead of wall-clock time. Setting `updated_at = now()` selects NOTHING and
   the run reports `MERGE 0`, which reads like the feature failing rather than the row never
   arriving. Use a timestamp past the current max, and `dbt run --select fct_order_items
   --full-refresh` afterwards to put the mart back. #}
{{ config(
    materialized='incremental',
    unique_key=['order_id', 'line_no'],
    incremental_strategy='merge',
    merge_exclude_columns=['loaded_at'],
    on_schema_change='fail',
    grants={'+select': ['finance_reader']}
) }}

with items as (
    select * from {{ ref('int_order_items_enriched') }}
),
orders as (
    select order_id, customer_id, created_at, updated_at, currency
    from {{ ref('stg_orders') }}
    where created_at <= {{ dbt.current_timestamp() }}
)

select
    items.order_id,
    items.line_no,
    orders.customer_id,
    items.product_id,
    items.product_name,
    items.category_id,
    items.quantity,
    items.unit_price_cents,
    items.unit_price_usd,
    items.line_total_cents,
    items.line_total_usd,
    orders.currency,
    orders.created_at as order_created_at,
    orders.updated_at as order_updated_at,
    items.loaded_at
from items
inner join orders using (order_id)

{#
   Two arms, for the reason fct_orders sets out at length: the `created_at <= now()` cut-off
   above means the clock alone can make a line eligible, and the clock does not move
   `order_updated_at`. The watermark arm catches CHANGED lines; the `not exists` arm catches
   lines that are newly ELIGIBLE but absent. The unique key is composite here, so the absence
   probe is too.

   The trap in the header comment survives this: an EXISTING line whose `updated_at` is set to
   `now()` is still selected by neither arm while the watermark sits in the future, and the run
   still reports `MERGE 0`.

   The comparison is `>=` for the reason `fct_orders` sets out at length: this reads a SOURCE
   clock, rows can share the stored high mark, and a strict `>` drops them permanently because
   the not-exists arm only rescues lines that are ABSENT, not lines that are present and wrong.
   Measured on the fixture, a line quantity corrected 3 -> 4 at an equal source watermark stayed
   at 3 after a green incremental run. `merge` on `['order_id','line_no']` makes the extra
   re-work idempotent.
#}
{% if is_incremental() %}
    where orders.updated_at >= (select coalesce(max(order_updated_at), '1900-01-01') from {{ this }})
       or not exists (
              select 1 from {{ this }} as prev
               where prev.order_id = items.order_id
                 and prev.line_no  = items.line_no
          )
{% endif %}
