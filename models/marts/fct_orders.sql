{# Incremental, delete+insert strategy, post_hook grant. on_schema_change: append_new_columns. #}
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

{% if is_incremental() %}
    where orders.updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
{% endif %}
