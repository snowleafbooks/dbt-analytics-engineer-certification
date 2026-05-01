-- Typo: `stg_orderz` instead of `stg_orders`.
select * from {{ ref('stg_orderz') }}
