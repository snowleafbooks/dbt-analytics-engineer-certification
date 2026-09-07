#!/usr/bin/env bash
# Materialized-view check. models/marts/mv_recent_orders.sql uses
# materialized='materialized_view' with on_configuration_change='apply'. Four assertions:
# the object really is a matview (not a view or a table), it is populated, REFRESH
# MATERIALIZED VIEW re-materializes the window the model defines, and that window is
# non-empty.
#
# The distinction a matview earns its keep on: a view is recomputed on every read, a matview
# holds whatever the last REFRESH captured. Postgres does not maintain it for you -- something
# has to issue the REFRESH -- and on an ordinary `dbt run` that something is dbt: with no
# configuration change the build SQL for this materialization *is* REFRESH MATERIALIZED VIEW.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PGPASSWORD="${POSTGRES_PASSWORD:-dbt_developer_pw}"
PSQL="${PSQL:-psql -h ${POSTGRES_HOST:-postgres} -p ${POSTGRES_PORT:-5432}}"
PGUSER_="${POSTGRES_USER:-dbt_developer}"
PGDB_="${POSTGRES_DB:-dbtae}"
SCHEMA="${DBT_SCHEMA:-dev}"

q() { $PSQL -U "$PGUSER_" -d "$PGDB_" -tAc "$1"; }

fail=0
assert() {
    if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 (expected '$2', got '$3')"; fail=1; fi
}

echo "--- object kind ---"
$PSQL -U "$PGUSER_" -d "$PGDB_" -c "
select schemaname, matviewname, ispopulated from pg_matviews
 where schemaname='$SCHEMA' and matviewname='mv_recent_orders';"

assert "mv_recent_orders is a materialized view" 1 \
    "$(q "select count(*) from pg_matviews where schemaname='$SCHEMA' and matviewname='mv_recent_orders'")"
assert "and not a plain view"  0 "$(q "select count(*) from pg_views  where schemaname='$SCHEMA' and viewname='mv_recent_orders'")"
assert "and not a table"       0 "$(q "select count(*) from pg_tables where schemaname='$SCHEMA' and tablename='mv_recent_orders'")"
assert "it is populated"       t "$(q "select ispopulated from pg_matviews where schemaname='$SCHEMA' and matviewname='mv_recent_orders'")"

echo ""
echo "--- refresh cycle ---"
# What NOT to assert here: `before == after`. That asserts REFRESH is a no-op, which is the
# opposite of the lesson -- and it is simply false on any day the matview was not rebuilt,
# because the model's window is `created_at >= current_date - interval '7 days'` and that
# window slides every calendar day. Run the suite the morning after a build and the equality
# fails while nothing is wrong. The assertion that both holds and teaches is that after
# REFRESH the stored copy agrees with the window as it stands right now.
live=$(q "select count(*) from $SCHEMA.fct_orders where created_at >= current_date - interval '7 days'")
before=$(q "select count(*) from $SCHEMA.mv_recent_orders")
q "refresh materialized view $SCHEMA.mv_recent_orders" >/dev/null
after=$(q "select count(*) from $SCHEMA.mv_recent_orders")
printf '  %-30s = %s\n' "rows stored before REFRESH" "$before"
printf '  %-30s = %s\n' "rows in the window right now" "$live"
printf '  %-30s = %s\n' "rows stored after REFRESH" "$after"
assert "REFRESH re-materialized the current window" "$live" "$after"
if [ "$before" != "$after" ]; then
    echo "  note the stored copy was stale ($before -> $after) until this REFRESH -- which is"
    echo "       exactly what separates a materialized view from a view."
fi

# The model filters `created_at >= current_date - interval '7 days'`. An empty result is a
# real failure, not a quirk: it means the fixture data no longer reaches today, and the
# whole matview demonstration silently prints zero for every reader.
if [ "$after" -gt 0 ]; then
    echo "  ok   the 7-day window is non-empty ($after rows)"
else
    echo "  FAIL the 7-day window is empty -- the seed data no longer covers today."
    echo "       Regenerate the fixture (scripts/generate_data.py) rather than widening the filter."
    fail=1
fi

exit $fail
