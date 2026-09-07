#!/usr/bin/env bash
set -euo pipefail

# dbt clone against the prior-artifacts baseline.
# On Postgres this is NOT a zero-copy clone — dbt falls back to CREATE VIEW AS SELECT *,
# so the clones are pointers into the baseline schema. Useful for simulating a CI
# "shadow" environment; not equivalent to Snowflake / Databricks zero-copy.
#
# Usage:  ./scripts/clone-demo.sh

cd "$(dirname "$0")/.."

DBT="${DBT:-dbt}"

if [[ ! -f prior-artifacts/manifest.json ]]; then
    echo "prior-artifacts/manifest.json not found — run ./scripts/save-baseline.sh first." >&2
    exit 1
fi

# --full-refresh is not optional here. Run this after scripts/slim-ci.sh — which is the order
# the README introduces them in — and ci.fct_order_items already exists as a TABLE that slim CI
# built. Without --full-refresh, dbt clone declines to replace it, logs one grey line
# (`Relation "dbtae"."ci"."fct_order_items" already exists`) and still reports
# `Done. PASS=2 ... TOTAL=2` with exit 0 — so the demo half-succeeds while claiming to have
# landed two views, and the reader is looking at a table.
"$DBT" clone \
    --target ci \
    --state ./prior-artifacts \
    --select fct_orders fct_order_items \
    --full-refresh
