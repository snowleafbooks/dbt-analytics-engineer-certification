#!/usr/bin/env bash
# `identifier:` check. models/sources.yml declares a source table named `product_catalog`
# with `identifier: products`, so source('raw_ecom','product_catalog') must resolve to the
# warehouse relation raw_ecom.products -- and no row is lost on the way through.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DBT="${DBT:-dbt}"
export DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-$HOME/.dbt}"
export PGPASSWORD="${POSTGRES_PASSWORD:-dbt_developer_pw}"
PSQL="${PSQL:-psql -h ${POSTGRES_HOST:-postgres} -p ${POSTGRES_PORT:-5432}}"
PGUSER_="${POSTGRES_USER:-dbt_developer}"
PGDB_="${POSTGRES_DB:-dbtae}"
SCHEMA="${DBT_SCHEMA:-dev}"

# COMPILE EVERY TIME, and into a target path of this script's own.
#
# The obvious shortcut -- reuse target/compiled/... when it is already there -- makes this
# verifier report on whatever the last command happened to leave behind. Measured, 2026-09-06:
# point `identifier:` at a nonexistent table in a scratch copy of the project and the
# skip-if-present form still exited 0, because it was reading a compiled file produced before
# the change. Compiling first, the same check exited 1. A verifier that can pass on a stale
# artifact is not a verifier.
#
# --target-path keeps that compile out of target/, so running this script never clobbers the
# run_results.json that the `result:` and `--state` demos are reading.
COMPILE_DIR="$(mktemp -d)"
trap 'rm -rf "$COMPILE_DIR"' EXIT
"$DBT" compile --select stg_products --target-path "$COMPILE_DIR" >/dev/null
COMPILED="$COMPILE_DIR/compiled/dbtae_companion/models/staging/stg_products.sql"
[ -f "$COMPILED" ] || { echo "FAIL dbt compile produced no $COMPILED" >&2; exit 1; }

fail=0

echo "--- stg_products compiled SQL should reference raw_ecom.products, not product_catalog ---"
grep -E 'from +"[^"]+"\."[^"]+"\."[^"]+"' "$COMPILED" | head -3
if grep -q '"products"' "$COMPILED" && ! grep -q '"product_catalog"' "$COMPILED"; then
    echo "  ok   resolved through identifier: to raw_ecom.products"
else
    echo "  FAIL compiled SQL does not resolve through identifier:"
    fail=1
fi

echo ""
echo "--- row count through the chain ---"
raw=$($PSQL -U "$PGUSER_" -d "$PGDB_" -tAc "select count(*) from raw_ecom.products")
stg=$($PSQL -U "$PGUSER_" -d "$PGDB_" -tAc "select count(*) from $SCHEMA.stg_products")
printf '  %-22s = %s\n' "raw_ecom.products"      "$raw"
printf '  %-22s = %s\n' "$SCHEMA.stg_products"   "$stg"
if [ "$raw" = "$stg" ] && [ "$raw" -gt 0 ]; then
    echo "  ok   row count preserved end to end"
else
    echo "  FAIL row counts differ or are empty (run dbt build first)"
    fail=1
fi

exit $fail
