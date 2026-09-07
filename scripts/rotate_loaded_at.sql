-- Bumps loaded_at on the orders source so `source_status:fresher+` picks up changes
-- when run against a prior sources.json baseline.
--
-- The bump is relative to the table's own maximum, not to now(). `source_status:fresher+`
-- compares max(loaded_at) against the baseline's max_loaded_at, and the data-seed fixture
-- is generated ~2 years ahead of wall clock (see data-seed/GENERATED.md) — so writing
-- now() here would *lower* those rows and leave max(loaded_at) untouched, selecting nothing.
--
-- Workflow:
--   1. dbt source freshness                          # produces target/sources.json
--   2. ./scripts/save-baseline.sh                    # freeze as prior-artifacts/sources.json
--   3. psql -f scripts/rotate_loaded_at.sql          # mutate loaded_at
--   4. dbt source freshness                          # re-run
--   5. dbt build --select source_status:fresher+ --state ./prior-artifacts
--
-- For the opposite demo — making sources report STALE — see scripts/force_stale.sql
-- and its inverse scripts/restore_freshness.sql.

\set ON_ERROR_STOP on

UPDATE raw_ecom.orders
   SET loaded_at = (SELECT max(loaded_at) FROM raw_ecom.orders) + interval '1 hour'
 WHERE order_id <= 50;

SELECT 'rotated ' || count(*) || ' rows to ' || max(loaded_at) AS result
  FROM raw_ecom.orders
 WHERE loaded_at = (SELECT max(loaded_at) FROM raw_ecom.orders);
