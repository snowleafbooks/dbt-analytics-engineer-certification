#!/usr/bin/env bash
set -e
cd /workspaces/dbt-analytics-engineer-certification
export DBT_PROFILES_DIR=/home/vscode/.dbt
export PGPASSWORD=dbt_developer_pw

echo "--- drop existing ci relations ---"
psql -h postgres -U dbt_developer -d dbtae -c "drop table if exists ci.fct_orders cascade; drop table if exists ci.fct_order_items cascade;" 2>&1

echo ""
echo "--- dbt clone into ci from baseline in dev ---"
dbt clone --target ci --state ./prior-artifacts --select fct_orders fct_order_items 2>&1 | tail -20

echo ""
echo "--- verify relations + kind (table / view) ---"
psql -h postgres -U dbt_developer -d dbtae -c "select schemaname, tablename, 'table' as kind from pg_tables where schemaname='ci' and tablename in ('fct_orders','fct_order_items') union all select schemaname, viewname, 'view' from pg_views where schemaname='ci' and viewname in ('fct_orders','fct_order_items');"

echo ""
echo "--- row count in cloned fct_orders ---"
psql -h postgres -U dbt_developer -d dbtae -c "select count(*) from ci.fct_orders;"
