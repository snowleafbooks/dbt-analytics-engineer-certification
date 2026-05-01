{#
    Custom generic test: fails for rows where the column value falls outside [min_value, max_value].
    Invocable in YAML as:
        data_tests:
          - value_in_range:
              min_value: 0
              max_value: 100000
#}
{% test value_in_range(model, column_name, min_value, max_value) %}

    select {{ column_name }}
    from {{ model }}
    where {{ column_name }} < {{ min_value }}
       or {{ column_name }} > {{ max_value }}

{% endtest %}
