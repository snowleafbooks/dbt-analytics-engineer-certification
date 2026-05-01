{% macro audit_columns() %}
    '{{ target.name }}'::varchar                                    as dbt_target,
    '{{ target.schema }}'::varchar                                  as dbt_schema,
    cast('{{ run_started_at }}' as timestamp)                       as dbt_run_started_at
{% endmacro %}
