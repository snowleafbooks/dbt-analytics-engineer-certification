with source as (
    select * from {{ source('raw_ecom', 'orders') }}
),

renamed as (
    select
        {{ dbt_utils.star(
            from=source('raw_ecom', 'orders'),
            except=['order_total_cents']
        ) }},
        order_total_cents,
        {{ cents_to_dollars('order_total_cents') }} as order_total,
        {{ audit_columns() }}
    from source
)

select * from renamed
