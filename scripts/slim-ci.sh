#!/usr/bin/env bash
set -euo pipefail

# Canonical slim-CI recipe: run only the modified subtree, deferring unmodified
# upstreams to the baseline schema.
#
# Prereq:  ./scripts/save-baseline.sh has produced prior-artifacts/
# Usage:   ./scripts/slim-ci.sh

cd "$(dirname "$0")/.."

if [[ ! -f prior-artifacts/manifest.json ]]; then
    echo "prior-artifacts/manifest.json not found — run ./scripts/save-baseline.sh first." >&2
    exit 1
fi

dbt build \
    --target ci \
    --select state:modified+ \
    --defer \
    --state ./prior-artifacts
