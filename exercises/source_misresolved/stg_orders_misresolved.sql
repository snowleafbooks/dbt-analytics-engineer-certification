-- A perfectly ordinary staging model over a source that points at the wrong place.
-- Nothing is wrong with this file; the defect is in _source_misresolved.yml.
select
    order_id,
    customer_id,
    status
from {{ source('ecom_landing', 'orders') }}
