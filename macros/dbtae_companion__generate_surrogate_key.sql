{#
    Dispatch override of dbt_utils.generate_surrogate_key.
    Resolved ahead of dbt_utils via `dispatch:` in dbt_project.yml.

    Behavior difference: this project's override lower-cases and trims every field
    before hashing, so casing / whitespace drift at source doesn't produce a new key.
    Hashing primitive is still md5 (Postgres-built-in) via dbt.hash().
#}
{% macro dbtae_companion__generate_surrogate_key(field_list) %}
    {%- set fields = [] -%}
    {%- for field in field_list -%}
        {%- do fields.append(
            "coalesce(lower(trim(cast(" ~ field ~ " as " ~ dbt.type_string() ~ "))), '_dbt_null_')"
        ) -%}
    {%- endfor -%}

    md5(cast(concat({{ fields|join(", '-', ") }}) as varchar))
{% endmacro %}
