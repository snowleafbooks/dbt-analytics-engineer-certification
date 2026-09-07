{#
    Custom generic test: fails for rows where the column value falls outside [min_value, max_value].

    Invocable in YAML as below. Test arguments belong under `arguments:`; the older flat form
    (arguments as direct siblings of the test name) still parses but raises a deprecation
    under the `require_generic_test_arguments_property` behaviour flag, which this project
    sets in dbt_project.yml. See /reference/global-configs/behavior-changes.

        data_tests:
          - value_in_range:
              arguments:
                min_value: 0
                max_value: 100000
#}
{% test value_in_range(model, column_name, min_value, max_value) %}

    select {{ column_name }}
    from {{ model }}
    where {{ column_name }} < {{ min_value }}
       or {{ column_name }} > {{ max_value }}

{% endtest %}
