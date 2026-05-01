{# Singular test: an order's total must equal the sum of its line items (in cents). #}
with order_totals as (
    select
        order_id,
        order_total_cents
    from {{ ref('fct_orders') }}
),
item_totals as (
    select
        order_id,
        sum(line_total_cents) as items_total_cents
    from {{ ref('fct_order_items') }}
    group by 1
)

select
    o.order_id,
    o.order_total_cents,
    i.items_total_cents
from order_totals o
inner join item_totals i using (order_id)
where o.order_total_cents != i.items_total_cents
