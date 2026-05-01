{#
    Returns a WHERE clause that limits historical rows in dev/ci targets.
    In `prod`, returns an empty string (no filter).
#}
{% macro limit_data_in_dev(column_name, days=30) %}
    {% if target.name in ('dev', 'ci') %}
        where {{ column_name }} >= current_date - interval '{{ days }} days'
    {% endif %}
{% endmacro %}
