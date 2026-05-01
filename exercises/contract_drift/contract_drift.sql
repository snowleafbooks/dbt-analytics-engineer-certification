-- The .yml declares columns (order_id, status). The SQL below returns (order_id, status_label).
-- The column-name drift triggers the contract-preflight error.
{{ config(
    materialized='table',
    contract={'enforced': true}
) }}

select
    order_id,
    status as status_label
from {{ ref('stg_orders') }}
