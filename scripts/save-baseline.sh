#!/usr/bin/env bash
set -euo pipefail

# Snapshot the current target/ directory into prior-artifacts/ so subsequent
# state:modified / --defer / result:* demos have a baseline to diff against.
#
# Usage:  ./scripts/save-baseline.sh
#
# Run `dbt build` first so target/manifest.json and target/run_results.json exist.

cd "$(dirname "$0")/.."

if [[ ! -f target/manifest.json ]]; then
    echo "target/manifest.json not found — run \`dbt build\` first." >&2
    exit 1
fi

rm -rf prior-artifacts
mkdir -p prior-artifacts
cp target/manifest.json    prior-artifacts/
cp target/run_results.json prior-artifacts/ 2>/dev/null || true
cp target/sources.json     prior-artifacts/ 2>/dev/null || true
cp target/catalog.json     prior-artifacts/ 2>/dev/null || true

echo "Baseline saved:"
ls -la prior-artifacts/
