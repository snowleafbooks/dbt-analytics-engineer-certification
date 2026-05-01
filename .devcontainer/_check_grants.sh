#!/usr/bin/env bash
export PGPASSWORD=dbt_developer_pw
psql -h postgres -U dbt_developer -d dbtae <<'SQL'
SELECT table_schema, table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE grantee IN ('bi_reader','analytics_reader','finance_reader','marketing_reader')
 ORDER BY table_name, grantee, privilege_type;
SQL
