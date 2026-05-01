#!/usr/bin/env bash
set -e
export PGPASSWORD=dbt_developer_pw

psql -h postgres -U dbt_developer -d dbtae <<'SQL'
-- Confirm the object is a materialized view (not a regular view or table).
SELECT schemaname, matviewname, ispopulated
  FROM pg_matviews
 WHERE schemaname = 'dev' AND matviewname = 'mv_recent_orders';

SELECT count(*) AS row_count FROM dev.mv_recent_orders;

-- REFRESH demonstrates the user-driven refresh cycle Postgres requires.
REFRESH MATERIALIZED VIEW dev.mv_recent_orders;
SELECT 'refreshed' AS step, count(*) AS row_count_post_refresh FROM dev.mv_recent_orders;
SQL
