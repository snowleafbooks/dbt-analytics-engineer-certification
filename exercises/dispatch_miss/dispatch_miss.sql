select
    {{ i_am_not_implemented('product_id') }} as x
from {{ ref('stg_products') }}
