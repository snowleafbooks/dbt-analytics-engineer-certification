{# Postgres materialized view — requires manual REFRESH MATERIALIZED VIEW to repopulate.
   on_configuration_change controls what dbt does if the definition diverges from warehouse
   state: 'apply' drops and recreates, 'continue' ignores, 'fail' errors. #}
{{ config(
    materialized='materialized_view',
    on_configuration_change='apply'
) }}

select
    order_id,
    customer_id,
    country_code,
    status,
    order_total_usd,
    created_at
from {{ ref('fct_orders') }}
where created_at >= current_date - interval '7 days'
