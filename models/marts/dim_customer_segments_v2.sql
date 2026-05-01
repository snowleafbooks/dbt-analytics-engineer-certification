{# Version 2 — adds recency dimension to the segmentation. #}
with customers as (
    select * from {{ ref('dim_customers') }}
),

enriched as (
    select
        customer_id,
        orders_lifetime_usd,
        orders_lifetime_count,
        latest_order_at,
        case when latest_order_at >= current_date - interval '90 days' then 'active'
             when latest_order_at >= current_date - interval '365 days' then 'lapsed'
             else 'inactive'
        end as recency_band
    from customers
)

select
    customer_id::integer                             as customer_id,
    cast(
        case
            when orders_lifetime_usd >= 500 then 'high'
            when orders_lifetime_usd >= 100 then 'medium'
            else 'low'
        end as varchar(10)
    )                                                as spend_segment,
    cast(recency_band as varchar(10))                as recency_segment,
    orders_lifetime_count::integer                   as orders_lifetime_count,
    cast(orders_lifetime_usd as numeric(14, 2))      as orders_lifetime_usd,
    latest_order_at::timestamp                       as latest_order_at
from enriched
