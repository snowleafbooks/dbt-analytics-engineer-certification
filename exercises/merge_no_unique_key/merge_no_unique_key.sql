{{ config(
    materialized='incremental',
    incremental_strategy='merge'
) }}

-- BROKEN ON PURPOSE: `merge` with no `unique_key`.
--
-- Nothing here errors. The run exits 0, prints no warning, and quietly degrades to
-- append-only, so the table grows a duplicate row on every incremental run. The evidence
-- is in the COMPILED SQL, not in the console -- which is the whole reason this case exists.
select
    1 as id,
    'a' as val
