with source as (
    select * from {{ source('raw_ecom', 'order_items') }}
)

select
    order_id,
    line_no,
    product_id,
    quantity,
    unit_price_cents,
    {{ cents_to_dollars('unit_price_cents') }} as unit_price_usd,
    quantity * unit_price_cents                as line_total_cents,
    {{ cents_to_dollars('quantity * unit_price_cents') }} as line_total_usd,
    loaded_at
from source
