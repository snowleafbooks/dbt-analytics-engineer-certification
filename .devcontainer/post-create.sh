#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/dbt-analytics-engineer-certification

mkdir -p "$HOME/.dbt"
cp profiles.yml.example "$HOME/.dbt/profiles.yml"

python -m pip install --user --no-cache-dir -r requirements.txt

dbt deps

echo "--- dbt debug ---"
dbt debug || true

echo ""
echo "Setup complete. Try:  dbt seed && dbt build"
