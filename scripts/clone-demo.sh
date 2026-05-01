#!/usr/bin/env bash
set -euo pipefail

# dbt clone against the prior-artifacts baseline.
# On Postgres this is NOT a zero-copy clone — dbt falls back to CREATE VIEW AS SELECT *,
# so the clones are pointers into the baseline schema. Useful for simulating a CI
# "shadow" environment; not equivalent to Snowflake / Databricks zero-copy.
#
# Usage:  ./scripts/clone-demo.sh

cd "$(dirname "$0")/.."

if [[ ! -f prior-artifacts/manifest.json ]]; then
    echo "prior-artifacts/manifest.json not found — run ./scripts/save-baseline.sh first." >&2
    exit 1
fi

dbt clone \
    --target ci \
    --state ./prior-artifacts \
    --select fct_orders fct_order_items
