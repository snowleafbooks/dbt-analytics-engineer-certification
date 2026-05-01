{#
    Override of the default generate_schema_name.
    Default behavior concatenates target.schema + custom_schema_name: e.g. `dev_reporting`.
    This override keeps that behavior in dev/ci and uses the custom schema name verbatim in prod.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
