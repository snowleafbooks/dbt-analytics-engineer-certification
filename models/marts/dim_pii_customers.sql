{# Access-restricted: private + group pii. Cross-group refs will parse-fail. #}
{{ config(
    materialized='table',
    access='private',
    group='pii',
    tags=['pii', 'pii_gdpr']
) }}

select
    customer_id,
    email,
    first_name || ' ' || last_name  as full_name,
    address_line_1,
    city,
    postal_code,
    country_code
from {{ ref('stg_customers') }}
