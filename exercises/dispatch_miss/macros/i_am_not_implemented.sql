{#
    Dispatch wrapper with only a snowflake__ variant defined — no default__, no postgres__.
    On Postgres, resolution falls through to a miss.
#}
{% macro i_am_not_implemented(column_name) %}
    {{ return(adapter.dispatch('i_am_not_implemented')(column_name)) }}
{% endmacro %}

{% macro snowflake__i_am_not_implemented(column_name) %}
    to_varchar({{ column_name }})
{% endmacro %}
