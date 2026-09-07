#!/usr/bin/env bash
# `dbt clone` check. Clones two marts from the baseline manifest in prior-artifacts/ into
# the ci schema and verifies what landed.
#
# The teaching point is the fallback: Postgres has no zero-copy clone, so dbt creates a VIEW
# over the source relation instead of copying a table. That is why this script prints the
# object kind -- on Snowflake or BigQuery the same command produces a table.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DBT="${DBT:-dbt}"
export DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-$HOME/.dbt}"
export PGPASSWORD="${POSTGRES_PASSWORD:-dbt_developer_pw}"
PSQL="${PSQL:-psql -h ${POSTGRES_HOST:-postgres} -p ${POSTGRES_PORT:-5432}}"
PGUSER_="${POSTGRES_USER:-dbt_developer}"
PGDB_="${POSTGRES_DB:-dbtae}"

q() { $PSQL -U "$PGUSER_" -d "$PGDB_" -tAc "$1"; }

fail=0
assert() {
    if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 (expected '$2', got '$3')"; fail=1; fi
}

if [ ! -f prior-artifacts/manifest.json ]; then
    echo "FAIL precondition: prior-artifacts/manifest.json is missing." >&2
    echo "      prior-artifacts/ is gitignored, so a fresh clone of this repo does not carry it." >&2
    echo "      Build the baseline first:  bash scripts/save-baseline.sh --rebase" >&2
    exit 1
fi

echo "--- drop existing ci relations ---"
# Idempotency: a previous run of this script leaves ci.fct_orders and ci.fct_order_items behind
# as VIEWS (that is the teaching point below). `DROP TABLE IF EXISTS` raises a hard ERROR -- not
# a skip -- when the name it is given is a view, and psql aborts the whole -c batch on the first
# error, so a naive "drop table ...; drop view ..." pair fails on every run after the first.
# Dispatch on relkind instead, so this script is safe to run any number of times.
#
# AND NAME WHATEVER ELSE GOES WITH THEM. `cascade` reaches past the two relations this script
# owns into anything built on top of them -- in this project that is ci.mv_recent_orders, which
# a `dbt build --target ci` puts there. Measured, 2026-09-06: a dependent view over ci.fct_orders
# existed before this verifier ran and was gone afterwards, while the verifier reported success.
# Dependents are enumerated and PRINTED first, and RESTRICT is used when there are none, so the
# cascade only ever fires where it has just been announced.
deps=$(q "
select coalesce(string_agg(distinct dn.nspname || '.' || dc.relname, ', '), '')
  from pg_depend d
  join pg_rewrite rw   on rw.oid = d.objid
  join pg_class dc     on dc.oid = rw.ev_class
  join pg_namespace dn on dn.oid = dc.relnamespace
  join pg_class sc     on sc.oid = d.refobjid
  join pg_namespace sn on sn.oid = sc.relnamespace
 where d.classid = 'pg_rewrite'::regclass
   and sn.nspname = 'ci'
   and sc.relname in ('fct_orders', 'fct_order_items')
   and dc.relname not in ('fct_orders', 'fct_order_items')")

if [ -n "$deps" ]; then
    DROP_MODE=cascade
    echo "  note: these objects are built on the ci clones and go WITH them:"
    echo "          $deps"
    echo "        put them back with:  dbt build --target ci"
else
    DROP_MODE=restrict
    echo "  nothing depends on the ci clones; dropping with RESTRICT"
fi

$PSQL -U "$PGUSER_" -d "$PGDB_" -c "
do \$\$
declare r record;
begin
  for r in
    select c.relname, c.relkind
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'ci'
       and c.relname in ('fct_orders', 'fct_order_items')
  loop
    if r.relkind = 'v' then
      execute format('drop view %I.%I $DROP_MODE', 'ci', r.relname);
    elsif r.relkind = 'm' then
      execute format('drop materialized view %I.%I $DROP_MODE', 'ci', r.relname);
    else
      execute format('drop table %I.%I $DROP_MODE', 'ci', r.relname);
    end if;
    raise notice 'dropped ci.% (relkind %)', r.relname, r.relkind;
  end loop;
end
\$\$;"

echo ""
echo "--- dbt clone into ci from the prior-artifacts baseline ---"
# Do not pipe dbt straight into `tail` here. Under `set -euo pipefail` a failing clone kills
# the script on the pipeline itself, before ${PIPESTATUS[0]} is ever read, so the assert below
# becomes unreachable and the reader gets a raw Python traceback instead of a FAIL line.
# Capture to a file, keep the exit code, then show the tail.
clone_log="$(mktemp)"
clone_rc=0
"$DBT" clone --target ci --state ./prior-artifacts --select fct_orders fct_order_items \
    >"$clone_log" 2>&1 || clone_rc=$?
tail -8 "$clone_log"
rm -f "$clone_log"
assert "dbt clone exited cleanly" 0 "$clone_rc"
if [ "$clone_rc" != 0 ]; then
    echo "       nothing below is checkable without a successful clone." >&2
    exit 1
fi

echo ""
echo "--- what landed in ci ---"
$PSQL -U "$PGUSER_" -d "$PGDB_" -c "
select schemaname, tablename as relname, 'table' as kind from pg_tables
 where schemaname='ci' and tablename in ('fct_orders','fct_order_items')
union all
select schemaname, viewname, 'view' from pg_views
 where schemaname='ci' and viewname in ('fct_orders','fct_order_items');"

assert "both clones exist as VIEWS (Postgres has no zero-copy clone)" 2 \
    "$(q "select count(*) from pg_views where schemaname='ci' and viewname in ('fct_orders','fct_order_items')")"
assert "and not as tables" 0 \
    "$(q "select count(*) from pg_tables where schemaname='ci' and tablename in ('fct_orders','fct_order_items')")"

rows=$(q "select count(*) from ci.fct_orders")
echo "  rows visible through ci.fct_orders = $rows"
if [ "$rows" -gt 0 ]; then echo "  ok   the clone reads through to real data"; else echo "  FAIL clone is empty"; fail=1; fi

exit $fail
