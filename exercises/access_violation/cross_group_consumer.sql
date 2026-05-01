-- The consumer is in group `marketing`, but dim_pii_customers is private in group `pii`.
-- Parse fails with DbtReferenceError.
{{ config(group='marketing') }}

select customer_id, email
from {{ ref('dim_pii_customers') }}
