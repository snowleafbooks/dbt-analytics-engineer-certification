{# 
    `event_time` marks the column dbt uses to slice this relation into time windows.
    It does nothing on an ordinary run; it is consumed by microbatch models downstream
    and by `--sample`. See models/marts/fct_orders_microbatch.sql.
#}
{{ config(event_time='created_at') }}

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
