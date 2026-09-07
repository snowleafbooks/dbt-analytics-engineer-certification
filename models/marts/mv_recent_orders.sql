{# Postgres materialized view. Postgres does not maintain one automatically, so something
   has to REFRESH it — and on an ordinary `dbt run` that something is dbt: with the relation
   already present and no configuration change, the build SQL *is*
   `refresh materialized view <this>` — visible in `logs/dbt.log` under `--debug`. There is
   no manual step in the dbt workflow; the manual part is what happens between runs.
   on_configuration_change controls the CONFIG case only, and on dbt-postgres not even that reaches
   a changed `select`: postgres__describe_materialized_view returns the object's indexes and
   nothing else, so an edited query is not detected, the run reports REFRESH MATERIALIZED VIEW at
   exit 0, and the warehouse keeps the OLD definition until `dbt run --full-refresh`. For the
   config case, when the definition diverges from
   warehouse state: 'apply' drops and recreates, 'continue' ignores, 'fail' errors. #}
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
