{#
  Demonstrates `enabled: false`. This model is discoverable by dbt parse but is
  excluded from the DAG, from docs, and from every `dbt build`. Flip to true to
  experiment with how dbt responds when a downstream ref'ed model becomes disabled.
#}
{{ config(enabled=false) }}

select 1 as placeholder
