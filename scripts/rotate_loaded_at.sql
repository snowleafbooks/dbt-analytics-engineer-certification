-- Bumps loaded_at on the orders source so `source_status:fresher+` picks up changes
-- when run against a prior sources.json baseline.
--
-- Workflow:
--   1. dbt source freshness                          # produces target/sources.json
--   2. ./scripts/save-baseline.sh                    # freeze as prior-artifacts/sources.json
--   3. psql -f scripts/rotate_loaded_at.sql          # mutate loaded_at
--   4. dbt source freshness                          # re-run
--   5. dbt build --select source_status:fresher+ --state ./prior-artifacts

UPDATE raw_ecom.orders
   SET loaded_at = now()
 WHERE order_id <= 50;

SELECT 'rotated ' || count(*) || ' rows' AS result
  FROM raw_ecom.orders
 WHERE loaded_at >= now() - interval '1 minute';
