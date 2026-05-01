{# Version 1 — three-tier segmentation on lifetime spend. #}
with customers as (
    select * from {{ ref('dim_customers') }}
)

select
    customer_id::integer as customer_id,
    cast(
        case
            when orders_lifetime_usd >= 500 then 'high'
            when orders_lifetime_usd >= 100 then 'medium'
            else 'low'
        end as varchar(10)
    ) as segment
from customers
