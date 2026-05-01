{# Consumer pinning a specific model version (v=1). #}
with segments as (
    select * from {{ ref('dim_customer_segments', v=1) }}
),
orders as (
    select customer_id, count(*) as recent_orders
    from {{ ref('fct_orders') }}
    where created_at >= current_date - interval '30 days'
    group by 1
)

select
    segments.customer_id,
    segments.segment,
    coalesce(orders.recent_orders, 0) as recent_orders
from segments
left join orders using (customer_id)
