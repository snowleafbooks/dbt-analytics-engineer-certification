-- A contracted model. The YAML alongside puts a `check` constraint on `price_cents`
-- but never declares that column's `data_type`, so dbt cannot build the DDL.
{{ config(
    materialized='table',
    contract={'enforced': true}
) }}

select
    product_id::integer   as product_id,
    price_cents::integer  as price_cents
from {{ ref('stg_products') }}
