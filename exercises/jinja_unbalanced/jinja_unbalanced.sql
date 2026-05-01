{# Missing {% endif %} — the Jinja parser raises before SQL ever compiles. #}

select
    order_id,
    {% if target.name == 'prod' %}
        'prod-flag' as env_label
    from {{ ref('stg_orders') }}
