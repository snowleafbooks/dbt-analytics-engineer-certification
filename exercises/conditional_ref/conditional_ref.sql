-- Two `ref()` calls, one file. Only the branch Jinja actually takes is rendered, so only that
-- branch's `ref()` ever runs -- and the graph is built from the calls that ran.
--
-- Flip `use_products` at parse time and this model's parent changes. Nothing about the file
-- changed; the DAG did.
{% if var('use_products', false) %}
select product_id as id from {{ ref('stg_products') }}
{% else %}
select order_id as id from {{ ref('stg_orders') }}
{% endif %}
