-- `price_cents` is unquoted, so Jinja reads it as a VARIABLE, not as the string "price_cents".
-- No such variable exists, so it resolves to Undefined, renders as the empty string, and the
-- macro dutifully builds `cast( as numeric)` around nothing.
--
-- The fix is one pair of quotes: cents_to_dollars('price_cents').
select
    {{ cents_to_dollars(price_cents) }} as price_usd
from {{ ref('stg_products') }}
