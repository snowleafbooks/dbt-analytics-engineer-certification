#!/usr/bin/env bash
#
# Put the warehouse back the way a fresh clone finds it.
#
#   bash scripts/reset-warehouse.sh                # raw data + this project's schemas, then rebuild
#   bash scripts/reset-warehouse.sh --raw-only     # only raw_ecom / raw_ref
#   bash scripts/reset-warehouse.sh --deep         # also drop schemas this project did not create
#   bash scripts/reset-warehouse.sh --no-rebuild   # reset, but do not run dbt afterwards
#   bash scripts/reset-warehouse.sh --yes          # skip the confirmation
#
# WHY THIS EXISTS, AND WHY `--full-refresh` IS NOT ENOUGH
#
#   Practising here writes to places a rebuild cannot reach back into:
#
#     raw_ecom / raw_ref   scripts/force_stale.sql, scripts/rotate_loaded_at.sql and
#                          scripts/mutate-customers.sql all UPDATE the source tables, and the
#                          exercises invite you to do the same. `restore_freshness.sql` reverses
#                          exactly one of those mutations; nothing reverses the rest.
#     snapshots            a snapshot ACCUMULATES history. Re-running it adds another version;
#                          it cannot un-record the one you just made. `dev_snapshots` is the
#                          only relation in the project where a rerun is not a repair.
#     stray schemas        every `--target`, every custom `schema:`, every hand-run probe leaves
#                          one behind, and dbt never removes a schema it created.
#
#   `db-init/*.sql` does NOT run again on a container restart: Postgres executes
#   /docker-entrypoint-initdb.d only when the data directory is empty. So without this script the
#   only full reset is deleting the volume and rebuilding the container.
#
# WHY NOT JUST KEEP A COPY OF THE POSTGRES DATA FILES AND PUT THEM BACK?
#
#   Because a copy of a running server's data directory is not a backup -- it is a torn one. The
#   files change under you mid-copy, so you get a mix of two states that may not even start; that
#   is the entire reason `pg_basebackup` and `pg_dump` exist. Doing it safely means stopping the
#   container for every snapshot and every restore. The copy is also opaque (you cannot read a
#   diff of it), tied to the PostgreSQL major version and platform that wrote it, and far larger
#   than the ~20,000 rows it encodes.
#
#   This repo already ships the real source of truth as plain text: `data-seed/*.csv` plus the
#   DDL in `db-init/`. Restoring from those is exact, reviewable, diffable, and takes seconds.
#   If you do want a byte-level rollback, take it at the DOCKER VOLUME level rather than the file
#   level -- stop the stack, `docker volume rm` the postgres volume, bring it back up, and
#   db-init runs again from scratch. That is the same result as `--deep`, more slowly.
#
# THE REPO'S OWN FILES ARE NOT THIS SCRIPT'S JOB. Exercises tell you to edit YAML and SQL; `git
# restore .` and `git clean -fd exercises/` put those back, and this script never touches them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DBT="${DBT:-dbt}"
export DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-$HOME/.dbt}"
export PGPASSWORD="${POSTGRES_PASSWORD:-dbt_developer_pw}"
PSQL="${PSQL:-psql -h ${POSTGRES_HOST:-postgres} -p ${POSTGRES_PORT:-5432}}"
PGUSER_="${POSTGRES_USER:-dbt_developer}"
PGDB_="${POSTGRES_DB:-dbtae}"
# db-init/02 and /03 name `raw_ecom` and `raw_ref` literally, so those are the schemas this
# script can put back. Pointing RAW_SCHEMA_ECOM / RAW_SCHEMA_REF elsewhere moves where the SOURCE
# resolves, not where db-init builds; say so rather than resetting a schema nobody is reading.
RAW_ECOM=raw_ecom
RAW_REF=raw_ref
if [ "${RAW_SCHEMA_ECOM:-raw_ecom}" != "raw_ecom" ] || [ "${RAW_SCHEMA_REF:-raw_ref}" != "raw_ref" ]; then
    echo "warning: RAW_SCHEMA_ECOM/RAW_SCHEMA_REF point the source somewhere other than the" >&2
    echo "         defaults, but db-init/ only builds raw_ecom and raw_ref. This resets those." >&2
fi

RAW_ONLY=0; DEEP=0; REBUILD=1; ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --raw-only)   RAW_ONLY=1 ;;
        --deep)       DEEP=1 ;;
        --no-rebuild) REBUILD=0 ;;
        --yes|-y)     ASSUME_YES=1 ;;
        -h|--help)    sed -n '3,9p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *)            echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

# `</dev/null` on both is load-bearing, not tidiness. These get called from inside a
# `while read ... done < <(...)` loop, and a psql that inherits the loop's stdin swallows the
# rest of the table list: one table loads, the others silently do not, and `dbt build` then goes
# green over zero rows because not_null and unique pass vacuously on an empty relation. That is
# the same failure README.md warns about under `-v ON_ERROR_STOP=1`, and it bit this script.
q()   { $PSQL -U "$PGUSER_" -d "$PGDB_" -tAc "$1" </dev/null; }
run() { $PSQL -U "$PGUSER_" -d "$PGDB_" -v ON_ERROR_STOP=1 -q "$@" </dev/null; }
# Feed .sql files on STDIN rather than with -f. Same reason the CSV reload uses `FROM STDIN`:
# the documented `PSQL='docker exec -i devcontainer-postgres-1 psql'` escape hatch runs the
# client inside the container, where a repo-relative path does not exist. STDIN always crosses.
run_file() { $PSQL -U "$PGUSER_" -d "$PGDB_" -v ON_ERROR_STOP=1 -q < "$1"; }

# ---------------------------------------------------------------- what will be dropped
#
# The project's own schemas are ASKED FOR, not listed here. dbt knows where every node lands --
# including the `_snapshots`, `_reference` and `_finance_reporting` suffixes generate_schema_name
# produces -- and a hand-maintained list in this script would be one more copy to go stale.
project_schemas() {
    local target out
    for target in dev ci; do
        # --exclude-resource-type source, or the SOURCE schemas come back in this list and the
        # project-schema drop below deletes the raw layer that was just reloaded.
        out=$("$DBT" ls --target "$target" --exclude-resource-type source                 --output json --output-keys schema 2>/dev/null || true)
        printf '%s\n' "$out" | sed -n 's/.*"schema": *"\([^"]*\)".*/\1/p'
    done | sort -u
}

echo "==> asking dbt where this project writes"
mapfile -t SCHEMAS < <(project_schemas)
if [ ${#SCHEMAS[@]} -eq 0 ]; then
    echo "  ! dbt ls returned no schemas -- falling back to the profile defaults" >&2
    SCHEMAS=(dev ci)
fi
# `store_failures` writes into a sibling `<schema>_dbt_test__audit`. dbt ls already names it for
# any test configured that way; add it for the rest, and never stack the suffix on itself.
EXTRA=()
for s in "${SCHEMAS[@]}"; do
    case "$s" in
        *_dbt_test__audit) ;;
        *) EXTRA+=("${s}_dbt_test__audit") ;;
    esac
done
mapfile -t SCHEMAS < <(printf '%s
' "${SCHEMAS[@]}" "${EXTRA[@]}" | sort -u)

KEEP="'public','information_schema','$RAW_ECOM','$RAW_REF'"
if [ "$DEEP" = 1 ]; then
    mapfile -t STRAYS < <(q "select nspname from pg_namespace
                             where nspname not like 'pg\\_%'
                               and nspname not in ($KEEP)
                             order by 1")
fi

echo
echo "This will DROP and rebuild:"
echo "  raw source schemas   $RAW_ECOM, $RAW_REF   (reloaded from data-seed/*.csv)"
if [ "$RAW_ONLY" = 0 ]; then
    echo "  project schemas      ${SCHEMAS[*]}"
fi
if [ "$DEEP" = 1 ]; then
    echo "  stray schemas        ${#STRAYS[@]} not created by this project:"
    printf '                       %s\n' "${STRAYS[@]}"
fi
echo "  snapshot history     GONE -- this is the part a rebuild cannot restore"
echo
echo "It will NOT touch: your repo files, your profiles.yml, or the roles from db-init/01."
if [ "$ASSUME_YES" = 0 ]; then
    read -r -p "Type 'reset' to continue: " reply
    [ "$reply" = "reset" ] || { echo "aborted."; exit 1; }
fi

# ---------------------------------------------------------------- raw layer
echo
echo "==> dropping and recreating the raw schemas"
run -c "drop schema if exists \"$RAW_ECOM\" cascade; drop schema if exists \"$RAW_REF\" cascade;"
run_file db-init/02-schemas.sql
run_file db-init/03-raw-tables.sql

# The relation -> CSV mapping lives in db-init/04-load-raw.sql and is READ from there rather than
# repeated here. That file uses container-absolute paths (`/data-seed/...`), which only resolve
# for a psql running inside the compose stack; feeding the file on STDIN instead works from the
# host, from the devcontainer, and through `PSQL='docker exec -i ...'` alike.
echo "==> reloading raw tables from data-seed/"
loaded=0
while read -r relation csv; do
    [ -f "data-seed/$csv" ] || { echo "  ! data-seed/$csv is missing" >&2; exit 1; }
    $PSQL -U "$PGUSER_" -d "$PGDB_" -v ON_ERROR_STOP=1 -q         -c "\COPY $relation FROM STDIN WITH (FORMAT csv, HEADER true)" < "data-seed/$csv"
    # COUNT WHAT LANDED AND COMPARE IT TO THE FILE. A load that lands nothing is the worst
    # outcome available here, because everything downstream still goes green: every not_null and
    # unique test passes vacuously on an empty relation. The CSV is the expected count, header
    # line excluded.
    rows=$(q "select count(*) from $relation")
    want=$(( $(wc -l < "data-seed/$csv") - 1 ))
    if [ "$rows" != "$want" ]; then
        echo "  ! $relation loaded $rows rows; data-seed/$csv holds $want" >&2
        exit 1
    fi
    printf '  %-28s %s rows
' "$relation" "$rows"
    loaded=$((loaded + 1))
done < <(awk 'index($1, "COPY") == 2 { match($0, /[A-Za-z0-9_]+[.]csv/)
                                       print $2, substr($0, RSTART, RLENGTH) }'              db-init/04-load-raw.sql)

# ...and that every table named in db-init/04 was reached at all. The loop above is fed by a
# process substitution, and a psql inside it that inherited the loop's stdin would swallow the
# rest of the list -- one table loaded, five skipped, build still green. Measured while writing
# this script, which is why both this check and the `</dev/null` on q()/run() are here.
want_tables=$(grep -c "COPY " db-init/04-load-raw.sql)
if [ "$loaded" != "$want_tables" ]; then
    echo "  ! reloaded $loaded of the $want_tables tables db-init/04-load-raw.sql names" >&2
    exit 1
fi

# ---------------------------------------------------------------- built layer
if [ "$RAW_ONLY" = 0 ]; then
    echo "==> dropping this project's schemas"
    for s in "${SCHEMAS[@]}"; do
        run -c "drop schema if exists \"$s\" cascade;"
        echo "  dropped $s"
    done
fi

if [ "$DEEP" = 1 ] && [ "${#STRAYS[@]}" -gt 0 ]; then
    echo "==> dropping stray schemas"
    for s in "${STRAYS[@]}"; do
        run -c "drop schema if exists \"$s\" cascade;"
        echo "  dropped $s"
    done
fi

# ---------------------------------------------------------------- rebuild
if [ "$REBUILD" = 1 ]; then
    echo
    echo "==> $DBT build --full-refresh"
    "$DBT" build --full-refresh
    echo
    echo "Warehouse reset. The teaching baseline in prior-artifacts/ is now older than this"
    echo "build; rebuild it before any state: / --defer / clone demo:"
    echo "  bash scripts/save-baseline.sh --rebase"
else
    echo
    echo "Reset done, nothing rebuilt. Next:"
    echo "  $DBT build --full-refresh"
    echo "  bash scripts/save-baseline.sh --rebase"
fi
