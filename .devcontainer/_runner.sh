#!/usr/bin/env bash
set -e
cd /workspaces/dbt-analytics-engineer-certification
mkdir -p /home/vscode/.dbt
cp profiles.yml.example /home/vscode/.dbt/profiles.yml
export DBT_PROFILES_DIR=/home/vscode/.dbt
exec "$@"
