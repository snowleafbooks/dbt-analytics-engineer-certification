-- Missing `dbt_utils.` namespace prefix. dbt_utils' macro lives at dbt_utils.generate_surrogate_key.
-- Calling it bare only works if the current project has its own generate_surrogate_key macro
-- (or a dispatch target). This repo's override is named dbtae_companion__generate_surrogate_key,
-- so the bare name `generate_surrogate_key(...)` resolves to nothing.
select
    {{ generate_surrogate_key(['customer_id']) }} as cust_pk,
    *
from {{ ref('stg_customers') }}
