{# Demonstrates an inline config() block, and what precedence looks like when nothing is
   actually in conflict: `materialized` restates the folder default, and _staging__models.yml
   declares no config for this model, so the only observable contribution is `tags`, which are
   ADDITIVE to the folder's rather than replacing them. Check with
   `dbt ls --select stg_customers --resource-type model --output json --output-keys name config`
   -- tags come back as ['staging', 'customers', 'pii_adjacent']. #}
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
