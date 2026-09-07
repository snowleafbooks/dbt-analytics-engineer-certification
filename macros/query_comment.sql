{#
    Emits a JSON comment appended to every query dbt sends to the warehouse -- appended,
    not prepended, because dbt_project.yml's `query-comment:` block sets `append: true`.
    Drop that flag and dbt puts the comment in front of the statement instead.

    The comment is added as the statement leaves dbt, so it is not in `target/compiled/` or
    `target/run/`. Observable in the warehouse's query log (`log_statement = 'all'`, or
    `pg_stat_statements`), and in dbt's own `logs/dbt.log` under `--debug`.
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
