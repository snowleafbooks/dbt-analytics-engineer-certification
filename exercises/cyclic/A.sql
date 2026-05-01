-- Refs B, which refs A — dbt parse detects the cycle.
select * from {{ ref('B') }}
