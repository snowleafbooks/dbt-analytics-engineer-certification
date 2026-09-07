{#
    Returns a WHERE clause that limits historical rows in dev/ci targets.
    In `prod`, returns an empty string (no filter).

    Both bounds are deliberate. A lower bound alone (`>= current_date - N days`) reads like a
    "last N days" filter but is not one: this project's fixture is anchor-relative and carries
    forward-dated rows, so a lower-bound-only clause admits the recent window PLUS the entire
    future -- roughly 3,500 of 6,000 audit events rather than the ~140 the name implies. Both
    figures move a little day to day as the fixture's forward-dated rows mature. Any dataset
    with scheduled, forecast or pre-dated rows has the same property. The upper bound is what
    makes the macro do what it says.

    `< current_date + interval '1 day'` rather than `<= current_date` so that today's rows are
    kept whatever their time-of-day component.
#}
{% macro limit_data_in_dev(column_name, days=30) %}
    {% if target.name in ('dev', 'ci') %}
        where {{ column_name }} >= current_date - interval '{{ days }} days'
          and {{ column_name }} <  current_date + interval '1 day'
    {% endif %}
{% endmacro %}
