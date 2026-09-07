#!/usr/bin/env bash
set -euo pipefail

cd /workspaces/dbt-analytics-engineer-certification

# NEVER OVERWRITE AN EXISTING PROFILE. $HOME/.dbt is a named volume that survives "Rebuild
# Container", so an unconditional `cp` here discards whatever the reader changed -- their
# target, their host, their credentials -- every time they rebuild. Measured, 2026-09-06: a
# working profile on `target: ci` with a custom schema came back as the template's `target: dev`.
# Same rule, same wording, as .devcontainer/_runner.sh.
mkdir -p "$HOME/.dbt"
if [ ! -f "$HOME/.dbt/profiles.yml" ]; then
    cp profiles.yml.example "$HOME/.dbt/profiles.yml"
    echo "Wrote $HOME/.dbt/profiles.yml from profiles.yml.example."
elif ! grep -q '^dbtae_companion:' "$HOME/.dbt/profiles.yml"; then
    echo "warning: $HOME/.dbt/profiles.yml exists but declares no 'dbtae_companion:' profile." >&2
    echo "         Leaving it alone. Either merge in profiles.yml.example, or point" >&2
    echo "         DBT_PROFILES_DIR somewhere else, or dbt will fail to find the profile." >&2
else
    echo "Kept your existing $HOME/.dbt/profiles.yml -- it already has a dbtae_companion profile."
fi

python -m pip install --user --no-cache-dir -r requirements.txt

dbt deps

# SAY WHICH OUTCOME IT WAS. `dbt debug || true` followed by an unconditional "Setup complete"
# reported success over a refused connection: measured, 2026-09-06, by pointing POSTGRES_PORT at
# a closed port -- the connection error scrolled by and the last line on screen was "Setup
# complete", exit 0. The container genuinely is built here, so a failure is not fatal and this
# does not abort; what it must not do is call an unreachable warehouse "complete".
echo "--- dbt debug ---"
if dbt debug; then
    echo ""
    echo "Setup complete, warehouse reachable. Try:  dbt seed && dbt build"
else
    echo ""
    echo "Container built, but 'dbt debug' did NOT pass -- the project is not ready to run." >&2
    echo "Everything above installed; it is the warehouse connection that is wrong." >&2
    echo "Check that the postgres service is up and that POSTGRES_HOST / _PORT / _USER /" >&2
    echo "_PASSWORD / _DB agree with .devcontainer/docker-compose.yml, then:  dbt debug" >&2
fi
