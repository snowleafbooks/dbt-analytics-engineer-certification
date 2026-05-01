{# Table materialization (inherited from folder +materialized). Dispatch-resolved surrogate key. #}
with customers as (
    select * from {{ ref('stg_customers') }}
),
countries as (
    select * from {{ ref('country_codes') }}
),
orders as (
    select
        customer_id,
        count(*)                               as orders_lifetime_count,
        sum(order_total_cents) / 100.0         as orders_lifetime_usd,
        min(created_at)                        as first_order_at,
        max(created_at)                        as latest_order_at
    from {{ ref('stg_orders') }}
    group by 1
)

select
    customers.customer_pk,
    customers.customer_id,
    customers.email,
    customers.first_name,
    customers.last_name,
    customers.country_code,
    countries.country_name,
    countries.region,
    customers.city,
    customers.signed_up_at,
    coalesce(orders.orders_lifetime_count, 0)  as orders_lifetime_count,
    coalesce(orders.orders_lifetime_usd, 0)    as orders_lifetime_usd,
    orders.first_order_at,
    orders.latest_order_at
from customers
left join countries using (country_code)
left join orders    using (customer_id)
