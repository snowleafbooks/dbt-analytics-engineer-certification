-- Refs B, which refs A. `dbt parse` SURVIVES this; `dbt compile` is where the cycle is
-- detected -- see the README, which has the layer right.
select * from {{ ref('B') }}
