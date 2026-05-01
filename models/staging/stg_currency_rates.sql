select
    currency_code,
    usd_per_unit,
    rate_as_of,
    loaded_at
from {{ source('raw_ref', 'currency_rates') }}
