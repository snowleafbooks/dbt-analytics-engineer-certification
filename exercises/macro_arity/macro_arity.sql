-- Wrong kwarg name — cents_to_dollars takes `precision=`, not `precision_level=`.
select
    {{ cents_to_dollars('price_cents', precision_level=4) }} as price_usd
from {{ ref('stg_products') }}
