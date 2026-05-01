#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/dbt-analytics-engineer-certification

until pg_isready -h "${POSTGRES_HOST:-postgres}" -p "${POSTGRES_PORT:-5432}" -U "${POSTGRES_USER:-dbt_developer}" >/dev/null 2>&1; do
  sleep 1
done

echo "Postgres reachable. Profiles dir: ${DBT_PROFILES_DIR:-$HOME/.dbt}"
