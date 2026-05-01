{#
    Emits a JSON comment prepended to every query dbt sends to the warehouse.
    Observable via Postgres `pg_stat_statements` or `log_statement = 'all'`.
    Referenced from dbt_project.yml's `query-comment:` block.
#}
{% macro query_comment(node) %}
    {%- set comment_dict = {} -%}
    {%- do comment_dict.update(
        app='dbt',
        dbt_version=dbt_version,
        target=target.name,
        invocation_id=invocation_id,
        node_id=node.unique_id if node else none
    ) -%}
    {{ tojson(comment_dict) }}
{% endmacro %}
