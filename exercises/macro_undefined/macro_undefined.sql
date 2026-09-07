-- Missing package namespace. dbt_utils' macro lives at dbt_utils.generate_surrogate_key.
-- Calling it bare only resolves if the ROOT PROJECT defines a macro of that exact name.
-- This project's override is named default__generate_surrogate_key -- that is a dispatch
-- target, not a callable bare name -- so `generate_surrogate_key(...)` resolves to nothing.
select
    {{ generate_surrogate_key(['customer_id']) }} as cust_pk,
    *
from {{ ref('stg_customers') }}
