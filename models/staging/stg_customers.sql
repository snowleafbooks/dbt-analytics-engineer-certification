{# Demonstrates: inline config() override (wins over folder default 'view' and YAML config). #}
{{ config(
    materialized='view',
    tags=['customers', 'pii_adjacent']
) }}

with source as (
    select * from {{ source('raw_ecom', 'customers') }}
),

renamed as (
    select
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_pk,
        customer_id,
        lower(email)                                         as email,
        first_name,
        last_name,
        country_code,
        address_line_1,
        city,
        postal_code,
        signed_up_at,
        updated_at,
        loaded_at
    from source
)

select * from renamed
