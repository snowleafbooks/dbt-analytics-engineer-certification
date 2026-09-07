{# Incremental, delete+insert strategy. Two separate mechanisms, easily read as one:
   `post_hook` runs `analyze {{ this }}`, while `grants` is its own config -- and a `select:`
   key without the `+` REPLACES the project default rather than merging with it, which is the
   distinction `.devcontainer/_check_grants.sh` proves. on_schema_change: append_new_columns. #}
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns',
    tags=['daily', 'critical'],
    access='public',
    grants={'select': ['bi_reader']},
    post_hook=["analyze {{ this }}"]
) }}

with orders as (
    select * from {{ ref('stg_orders') }}
),
customers as (
    select customer_id, country_code, country_name from {{ ref('dim_customers') }}
),
rates as (
    select currency_code, usd_per_unit from {{ ref('stg_currency_rates') }}
)

select
    orders.order_id,
    orders.customer_id,
    customers.country_code,
    customers.country_name,
    orders.status,
    orders.currency,
    orders.order_total_cents,
    orders.order_total,
    round(orders.order_total * coalesce(rates.usd_per_unit, 1.0), 2) as order_total_usd,
    orders.created_at,
    orders.updated_at,
    orders.loaded_at,
    current_timestamp                                                  as dbt_updated_at
from orders
left join customers using (customer_id)
left join rates on orders.currency = rates.currency_code

{#
    Business rule, applied here and not in staging. The source carries scheduled and
    pre-ordered rows whose `created_at` is in the future; staging keeps them, because a
    staging model's job is to rename and recast, not to decide what counts. The mart is
    where "an order is a fact once it has actually happened" belongs, and
    tests/assert_no_future_orders.sql asserts the rule holds on this relation.

    `dbt.current_timestamp()` rather than a Postgres literal: the macro dispatches to
    whatever the active adapter's current-timestamp expression is, so this model compiles
    unchanged against another warehouse.
#}
where orders.created_at <= {{ dbt.current_timestamp() }}

{#
    THE INCREMENTAL PREDICATE HAS TWO ARMS, AND ONE ARM IS NOT ENOUGH.

    A watermark on `updated_at` answers "what CHANGED since the last run". That is the whole
    answer only when eligibility is fixed. Here it is not: the `where` above admits a row when
    the CLOCK passes its `created_at`, and the clock moves without anything at source being
    updated. A pre-order created for next Tuesday and last touched last March becomes a fact on
    Tuesday with an `updated_at` far BELOW the watermark -- so a watermark-only predicate skips
    it, and it stays missing until somebody updates that order or full-refreshes the mart. It is
    silent: the run exits 0 and every test passes, because nothing in the project asserts that
    the mart is COMPLETE.

    Measured on the fixture, 2026-09-06: 5 orders become eligible within the next day and 3 of
    them carry an `updated_at` below the current watermark. A full refresh returns all 5.

    So the second arm asks "what is ELIGIBLE but ABSENT", and the union of the two is the real
    change set. `not exists` rather than `not in`: `not in` against a subquery that can yield
    NULL evaluates to NULL for every row and selects nothing.

    AND THE COMPARISON IS `>=`, NOT `>`. This watermark reads a SOURCE column, so its clock is
    somebody else's: batch loaders stamp a whole delivery with one timestamp, and plenty of
    systems only keep a date. Rows can therefore SHARE the value this model stored as its high
    mark, and a strict `>` skips every one of them -- permanently, because the not-exists arm
    cannot rescue a row that is already in the target, only wrong. Measured: an order corrected
    from 10996 to 20996 cents at an equal source watermark stayed at 10996 after a green
    incremental run, tests and all.

    `>=` reprocesses the rows sharing that one timestamp. `unique_key='order_id'` with
    `delete+insert` replaces them, so a row recomputed is a row unchanged -- bounded, idempotent
    re-work in exchange for a silent, permanent miss.

    Contrast `fct_daily_sales`, whose watermark is `>` and should stay that way. It reads a
    column dbt itself writes (`dbt_updated_at`, one value per build), so the mark advances only
    when a NEW generation appears and ties cannot arise; `>=` there would recompute the same
    generation on every run forever. Strict or inclusive is decided by whose clock you are
    reading, not by preference.
#}
{% if is_incremental() %}
    and (
        orders.updated_at >= (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
        or not exists (select 1 from {{ this }} as prev where prev.order_id = orders.order_id)
    )
{% endif %}
