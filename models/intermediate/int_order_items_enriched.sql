{# Ephemeral — inlined as a CTE by any downstream ref(). Observable via target/compiled/. #}
with items as (
    select * from {{ ref('stg_order_items') }}
),
products as (
    select * from {{ ref('stg_products') }}
)

select
    items.order_id,
    items.line_no,
    items.product_id,
    products.product_name,
    products.category_id,
    items.quantity,
    items.unit_price_cents,
    items.unit_price_usd,
    items.line_total_cents,
    items.line_total_usd,
    items.loaded_at
from items
inner join products using (product_id)
