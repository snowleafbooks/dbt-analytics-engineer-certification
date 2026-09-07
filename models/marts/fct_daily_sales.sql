{# Incremental roll-up by day. Uses {{ this }} in predicate + {{ date_trunc_day() }} dispatch macro.

   WHY THE PREDICATE IS NOT `created_at >= max(sales_day)`.

   That is the obvious watermark for a daily roll-up and it is wrong, because the thing being
   watermarked is the wrong thing. `sales_day` is a BUSINESS date; the question this model has
   to answer is which days changed, and a day changes whenever any order in it changes -- which
   an order dated eighteen months ago can do at any time. Measured on the fixture, 2026-09-06:
   correct order 1 (2025-01-09) at source, rebuild `fct_orders`, rebuild here, and the mart
   still reported 314.56 for that day while `fct_orders` summed to 423.06. Both runs exited 0
   and every test passed, because the tests assert uniqueness and non-nullity of the roll-up,
   not that it agrees with its own parent.

   So the watermark is carried on the PARENT'S BUILD TIME instead, in `source_built_at`. Any
   `fct_orders` row written since this model last ran -- corrected, newly eligible, or brand new
   -- has a `dbt_updated_at` above the stored high-water mark, and its whole day is recomputed.
   `unique_key='sales_day'` with `delete+insert` then replaces those days outright, so a day is
   never double-counted.

   Storing the high-water mark in the target rather than deriving it from
   `max(fct_orders.dbt_updated_at)` at run time is the part that survives an unusual run order.
   Build `fct_orders` twice without building this model in between and a run-time max sees only
   the SECOND build's rows; the day the first build touched is lost. The stored mark advances
   only when this model actually consumes a generation.

   `source_built_at` IS A NEW COLUMN as of 2026-09-06, and it is the one shape change in this
   round. `on_schema_change: ignore` is deliberate here -- it is what the YAML's contract argument
   depends on -- and 'ignore' means an existing table does NOT grow the column on an incremental
   run. The predicate above then reads a column that is not there. Measured:

     Database Error in model fct_daily_sales (models/marts/fct_daily_sales.sql)
       column "source_built_at" does not exist
       LINE 25:     where dbt_updated_at > (select coalesce(max(source_built...

   One command fixes it, once, and a first build never sees it:

     dbt run --select fct_daily_sales --full-refresh

   `bash scripts/reset-warehouse.sh` does it too, along with everything else practice has moved. #}
{{ config(
    materialized='incremental',
    unique_key='sales_day',
    incremental_strategy='delete+insert',
    on_schema_change='ignore',
    tags=['daily', 'critical']
) }}

with orders as (
    select * from {{ ref('fct_orders') }}
)

{% if is_incremental() %}
, changed_days as (
    select distinct {{ date_trunc_day('created_at') }} as sales_day
    from orders
    where dbt_updated_at > (select coalesce(max(source_built_at), '1900-01-01') from {{ this }})
)
{% endif %}

select
    {{ date_trunc_day('created_at') }}   as sales_day,
    count(*)                              as orders_count,
    sum(order_total_usd)                  as revenue_usd,
    count(distinct customer_id)           as unique_customers,
    max(dbt_updated_at)                   as source_built_at
from orders
{% if is_incremental() %}
where {{ date_trunc_day('created_at') }} in (select sales_day from changed_days)
{% endif %}
group by 1
