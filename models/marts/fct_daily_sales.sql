{# Incremental roll-up by day. Uses {{ this }} in predicate + {{ date_trunc_day() }} dispatch macro. #}
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

select
    {{ date_trunc_day('created_at') }}   as sales_day,
    count(*)                              as orders_count,
    sum(order_total_usd)                  as revenue_usd,
    count(distinct customer_id)           as unique_customers
from orders
{% if is_incremental() %}
    where created_at >= (select coalesce(max(sales_day), '1900-01-01') from {{ this }})
{% endif %}
group by 1
