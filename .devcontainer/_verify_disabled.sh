#!/usr/bin/env bash
set -e
cd /workspaces/dbt-analytics-engineer-certification
export DBT_PROFILES_DIR=/home/vscode/.dbt

echo "--- total models in DAG ---"
dbt ls --resource-type model 2>/dev/null | grep -c '^dbtae_companion'

echo ""
echo "--- _example_disabled should NOT appear ---"
dbt ls --resource-type model 2>/dev/null | grep -i 'disabled' || echo "(absent — good)"

echo ""
echo "--- but --select with exact name should find it as disabled ---"
dbt ls --select _example_disabled 2>&1 | tail -3
