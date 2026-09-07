#!/usr/bin/env bash
# Run any command with this project's profile in place. Inside the devcontainer that is the
# one-liner that makes `dbt` work in a fresh shell; from a clone it does the same thing
# against your own $HOME.
#
#   bash .devcontainer/_runner.sh dbt build
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-$HOME/.dbt}"
mkdir -p "$DBT_PROFILES_DIR"

if [ ! -f "$DBT_PROFILES_DIR/profiles.yml" ]; then
    cp profiles.yml.example "$DBT_PROFILES_DIR/profiles.yml"
elif ! grep -q '^dbtae_companion:' "$DBT_PROFILES_DIR/profiles.yml"; then
    # An existing profiles.yml is never overwritten -- it is somebody's other project. But if
    # it has no dbtae_companion: profile, everything this wrapper execs fails with
    # "Could not find profile named 'dbtae_companion'", and the wrapper looks like the thing
    # that was supposed to prevent exactly that. Say so instead of silently doing nothing.
    echo "warning: $DBT_PROFILES_DIR/profiles.yml exists but declares no 'dbtae_companion:' profile." >&2
    echo "         Leaving it alone. Either merge in profiles.yml.example, or point" >&2
    echo "         DBT_PROFILES_DIR somewhere else, or dbt will fail to find the profile." >&2
fi

exec "$@"
