{# Incremental merge strategy (dbt-postgres 1.8 native MERGE on Postgres 15+).
   Composite unique_key; on_schema_change: sync_all_columns. Grants merge via '+select'. #}
{{ config(
    materialized='incremental',
    unique_key=['order_id', 'line_no'],
    incremental_strategy='merge',
    on_schema_change='sync_all_columns',
    grants={'+select': ['finance_reader']}
) }}

with items as (
    select * from {{ ref('int_order_items_enriched') }}
),
orders as (
    select order_id, customer_id, created_at, updated_at, currency from {{ ref('stg_orders') }}
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

{% if is_incremental() %}
    where orders.updated_at > (select coalesce(max(order_updated_at), '1900-01-01') from {{ this }})
{% endif %}
