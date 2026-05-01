{{ config(
    severity='warn',
    store_failures=true,
    store_failures_as='table',
    limit=500,
    tags=['critical']
) }}

select
    order_id,
    customer_id,
    created_at
from {{ ref('stg_orders') }}
where created_at > current_date + interval '1 day'
