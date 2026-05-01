{#
    Dispatch macro: truncate a timestamp to the day. Demonstrates the
    default__ / <adapter>__ pattern that dbt packages use to cover multiple adapters.
#}
{% macro date_trunc_day(column_name) %}
    {{ return(adapter.dispatch('date_trunc_day')(column_name)) }}
{% endmacro %}

{% macro default__date_trunc_day(column_name) %}
    cast(date_trunc('day', {{ column_name }}) as date)
{% endmacro %}

{% macro postgres__date_trunc_day(column_name) %}
    cast(date_trunc('day', {{ column_name }}) as date)
{% endmacro %}
