#!/usr/bin/env bash
# Grants behaviour check. Proves the three things dbt_project.yml and the mart models are
# built to teach:
#
#   replace  -- a model-level `grants={'select': [...]}` REPLACES the project default.
#               fct_orders should show bi_reader and NOT analytics_reader.
#   additive -- a model-level `grants={'+select': [...]}` MERGES with it.
#               fct_order_items should show analytics_reader AND finance_reader.
#   empty    -- a model-level `grants={'select': []}` is a replace with nothing.
#               dim_pii_customers should show NO grantee at all, while sitting in the same
#               folder as the models above. Deleting the config instead would leave dbt not
#               managing grants there, which is a different thing and not what is asserted.
#
# Run `dbt build` first; grants are applied when a model is built.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# psql transport. Defaults to a direct client, which is what the devcontainer has. From a
# host shell where the client only exists inside the container, override the whole prefix:
#   PSQL='docker exec -i devcontainer-postgres-1 psql' bash .devcontainer/_check_grants.sh
export PGPASSWORD="${POSTGRES_PASSWORD:-dbt_developer_pw}"
PSQL="${PSQL:-psql -h ${POSTGRES_HOST:-postgres} -p ${POSTGRES_PORT:-5432}}"
PGUSER_="${POSTGRES_USER:-dbt_developer}"
PGDB_="${POSTGRES_DB:-dbtae}"
SCHEMA="${DBT_SCHEMA:-dev}"

q() { $PSQL -U "$PGUSER_" -d "$PGDB_" -tAc "$1"; }

echo "--- all reader grants (schema: $SCHEMA) ---"
$PSQL -U "$PGUSER_" -d "$PGDB_" -c "
SELECT table_schema, table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE grantee IN ('bi_reader','analytics_reader','finance_reader','marketing_reader')
   AND table_schema = '$SCHEMA'
 ORDER BY table_name, grantee, privilege_type;"

fail=0
assert() {  # assert <label> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1 (expected '$2', got '$3')"
        fail=1
    fi
}

echo ""
echo "--- replace semantics: fct_orders overrides the project default ---"
assert "fct_orders granted to bi_reader" 1 \
    "$(q "select count(*) from information_schema.role_table_grants where table_schema='$SCHEMA' and table_name='fct_orders' and grantee='bi_reader' and privilege_type='SELECT'")"
assert "fct_orders NOT granted to analytics_reader" 0 \
    "$(q "select count(*) from information_schema.role_table_grants where table_schema='$SCHEMA' and table_name='fct_orders' and grantee='analytics_reader'")"

echo ""
echo "--- additive semantics: fct_order_items merges with the project default ---"
assert "fct_order_items granted to analytics_reader" 1 \
    "$(q "select count(*) from information_schema.role_table_grants where table_schema='$SCHEMA' and table_name='fct_order_items' and grantee='analytics_reader' and privilege_type='SELECT'")"
assert "fct_order_items granted to finance_reader" 1 \
    "$(q "select count(*) from information_schema.role_table_grants where table_schema='$SCHEMA' and table_name='fct_order_items' and grantee='finance_reader' and privilege_type='SELECT'")"

echo ""
echo "--- empty-list semantics: dim_pii_customers revokes the project default ---"
# The control comes first. dim_customers carries no grants config of its own, so it shows the
# inherited folder default -- which is what makes the zero below a result rather than an
# accident of nothing having been granted in this schema at all.
assert "dim_customers (control) granted to analytics_reader" 1     "$(q "select count(*) from information_schema.role_table_grants where table_schema='$SCHEMA' and table_name='dim_customers' and grantee='analytics_reader' and privilege_type='SELECT'")"
assert "dim_pii_customers NOT granted to analytics_reader" 0     "$(q "select count(*) from information_schema.role_table_grants where table_schema='$SCHEMA' and table_name='dim_pii_customers' and grantee='analytics_reader'")"
assert "dim_pii_customers has no reader grantee at all" 0     "$(q "select count(*) from information_schema.role_table_grants where table_schema='$SCHEMA' and table_name='dim_pii_customers' and grantee in ('bi_reader','analytics_reader','finance_reader','marketing_reader')")"

exit $fail
