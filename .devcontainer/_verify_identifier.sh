#!/usr/bin/env bash
set -e
cd /workspaces/dbt-analytics-engineer-certification
export DBT_PROFILES_DIR=/home/vscode/.dbt

echo "--- stg_products compiled SQL: should reference raw_ecom.products (not product_catalog) ---"
grep -A2 'from "dbtae"' target/compiled/dbtae_companion/models/staging/stg_products.sql | head -5

echo ""
echo "--- row count through the chain ---"
export PGPASSWORD=dbt_developer_pw
psql -h postgres -U dbt_developer -d dbtae -c "SELECT 'raw' AS source_of_truth, count(*) FROM raw_ecom.products UNION ALL SELECT 'stg via identifier alias', count(*) FROM dev.stg_products;"
