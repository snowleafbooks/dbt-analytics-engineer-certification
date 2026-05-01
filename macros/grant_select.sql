{#
    Callable via `dbt run-operation grant_select --args '{schema: marts, role: bi_reader}'`.
    Use `dry_run: true` to log without executing.
#}
{% macro grant_select(schema, role, dry_run=false) %}
    {% set sql %}
        grant select on all tables in schema {{ schema }} to {{ role }};
    {% endset %}

    {{ log("grant_select: target schema=" ~ schema ~ " role=" ~ role ~ " dry_run=" ~ dry_run, info=True) }}

    {% if execute and not dry_run %}
        {% do run_query(sql) %}
        {{ log("grant_select: executed.", info=True) }}
    {% else %}
        {{ log("grant_select: sql=" ~ sql, info=True) }}
    {% endif %}
{% endmacro %}
