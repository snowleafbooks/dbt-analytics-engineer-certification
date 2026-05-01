-- access: public + materialized: ephemeral is rejected at parse time.
-- Rationale: an ephemeral model has no warehouse identity; cross-project consumers can't
-- ref() something that only exists as a CTE.
{{ config(
    materialized='ephemeral',
    access='public'
) }}

select 1 as x
