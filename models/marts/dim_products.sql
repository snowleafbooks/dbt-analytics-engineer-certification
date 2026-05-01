{# Contracted model: every column declares data_type; constraints enforced at DDL. #}
{{ config(
    materialized='table',
    contract={'enforced': true}
) }}

with products as (
    select * from {{ ref('stg_products') }}
),
categories as (
    select * from {{ ref('product_categories') }}
)

select
    products.product_id::integer                       as product_id,
    products.sku::varchar(40)                          as sku,
    products.product_name::varchar(120)                as product_name,
    products.category_id::integer                      as category_id,
    categories.category_name::varchar(60)              as category_name,
    products.price_cents::integer                      as price_cents,
    cast(products.price_usd as numeric(12, 2))         as price_usd,
    products.is_active::boolean                        as is_active
from products
left join categories using (category_id)
