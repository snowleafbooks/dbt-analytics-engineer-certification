{#
    Incremental `append` -- a pure event stream with no unique key, so every run adds rows
    and never rewrites one. `full_refresh: false` protects the accumulated history from an
    accidental `dbt build --full-refresh`.

    `on_schema_change='sync_all_columns'` is the most permissive of the four modes: add a
    column upstream and dbt adds it here, drop one and dbt drops it. That is reasonable for
    an append-only log whose shape follows the source, and it is exactly what a contracted
    model may not do -- see fct_order_items, where dbt rejects the same setting because a
    contract is a promise about shape. The other two modes are also live in this project:
    `append_new_columns` on fct_orders, `ignore` on fct_daily_sales.
#}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    on_schema_change='sync_all_columns',
    full_refresh=false,
    tags=['audit']
) }}

select
    event_id,
    entity,
    entity_id,
    action,
    occurred_at,
    loaded_at
from {{ ref('stg_audit_events') }}

{% if is_incremental() %}
    where event_id > (select coalesce(max(event_id), 0) from {{ this }})
{% endif %}
