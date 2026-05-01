with source as (
    select * from {{ source('raw_ecom', 'product_catalog') }}
)

select
    product_id,
    sku,
    name                                         as product_name,
    category_id,
    price_cents,
    {{ cents_to_dollars('price_cents') }}        as price_usd,
    is_active,
    created_at,
    updated_at,
    loaded_at
from source
