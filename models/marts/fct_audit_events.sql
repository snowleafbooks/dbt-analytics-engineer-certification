{# Incremental append — pure event stream, no unique key. full_refresh: false protects from accidental wipe. #}
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    full_refresh=false,
    tags=['audit']
) }}

select
    event_id,
    entity,
    entity_id,
    action,
    occurred_at,
    loaded_at
from {{ ref('stg_audit_events') }}

{% if is_incremental() %}
    where event_id > (select coalesce(max(event_id), 0) from {{ this }})
{% endif %}
