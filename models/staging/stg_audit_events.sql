with source as (
    select * from {{ source('raw_ecom', 'audit_events') }}
)

select
    event_id,
    entity,
    entity_id,
    action,
    occurred_at,
    loaded_at
from source
{{ limit_data_in_dev('occurred_at') }}
