#!/usr/bin/env bash
set -euo pipefail

# Canonical slim-CI recipe: build only the modified subtree, deferring every unmodified
# upstream to the baseline's relations instead of rebuilding them.
#
# Prereq   prior-artifacts/ holds a baseline that actually differs from the working project.
#          `./scripts/save-baseline.sh --rebase` produces one; see
#          scripts/baseline-preimage/README.md for what the difference is.
#
# Usage    ./scripts/slim-ci.sh
#
# Environment
#   DBT    dbt executable (default: dbt)
#
# THE `ci` SCHEMA MUST BE EMPTY. Without `--favor-state`, dbt prefers a relation that already
# exists in the current target over the deferred one, so leftovers from an earlier run
# silently defeat the demo -- the run looks slim but is reading last week's tables. Clear it:
#
#   psql -c 'drop schema if exists ci cascade;'
#   psql -c 'drop schema if exists ci_snapshots cascade;'
#   psql -c 'drop schema if exists ci_reference cascade;'
#   psql -c 'drop schema if exists ci_dbt_test__audit cascade;'
#
# Or keep the schema and add `--favor-state`, which tells dbt to prefer the deferred relation
# even when a local one exists.

cd "$(dirname "$0")/.."
DBT="${DBT:-dbt}"

if [[ ! -f prior-artifacts/manifest.json ]]; then
    echo "prior-artifacts/manifest.json not found — run ./scripts/save-baseline.sh --rebase first." >&2
    exit 1
fi

"$DBT" build \
    --target ci \
    --select state:modified+ \
    --defer \
    --state ./prior-artifacts
