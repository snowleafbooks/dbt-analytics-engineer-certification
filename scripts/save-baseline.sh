#!/usr/bin/env bash
set -euo pipefail

# Save the four dbt artifacts that every state: / --defer / result: / source_status: demo in
# this repo diffs against, into prior-artifacts/.
#
# Usage
#   ./scripts/save-baseline.sh            snapshot the CURRENT project state
#   ./scripts/save-baseline.sh --rebase   rebuild the committed teaching baseline from
#                                         scripts/baseline-preimage/ (see its README)
#
# Environment
#   DBT   dbt executable (default: dbt)
#   PYTHON   python executable for artifact validation (default: python)
#
# WHY THIS IS NOT `cp target/*.json`
#
#   The four artifacts are written by four DIFFERENT commands, and each command overwrites
#   run_results.json on its way past:
#
#       manifest.json     any command that parses
#       run_results.json  the LAST command that ran nodes -- including `dbt compile` and
#                         `dbt docs generate`, which is how a baseline ends up with a
#                         one-result run_results.json and a dead `result:` demo.
#                         NOT `dbt ls`: measured on 1.11.14, `ls` leaves an existing
#                         run_results.json byte-identical and writes none when there is
#                         none. It is `compile` and `docs generate` that clobber it.
#       sources.json      `dbt source freshness` ONLY
#       catalog.json      `dbt docs generate` ONLY
#
#   Copying whatever happens to be sitting in target/ therefore yields a mixed-vintage
#   baseline. This script runs each producing command and copies its artifact out
#   immediately afterwards, so all four share one vintage.

cd "$(dirname "$0")/.."
DBT="${DBT:-dbt}"
PYTHON="${PYTHON:-python}"
PREIMAGE_DIR="scripts/baseline-preimage"
MODE="snapshot"

case "${1:-}" in
    --rebase)   MODE="rebase" ;;
    "")         ;;
    *)          echo "usage: $0 [--rebase]" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------- artifact capture

# CAPTURE INTO A STAGING DIRECTORY, PUBLISH ONCE.
#
# Two separate faults, both measured on 2026-09-06 by fault injection:
#
#   * `save_one` only asked whether target/<file> EXISTS. A leftover artifact from an earlier
#     run satisfies that, so a producing command that failed outright was recorded as a
#     successful capture. Each producer's output file is therefore REMOVED first: existence
#     afterwards then means this run wrote it.
#
#   * Artifacts were copied one at a time straight into the live prior-artifacts/. Injecting a
#     `docs generate` failure left a NEW manifest, run_results and sources sitting beside the
#     PREVIOUS catalog -- a mixed-vintage baseline, which is the exact thing the header above
#     says this script exists to prevent, and the known-good baseline was already gone.
#
# So nothing touches prior-artifacts/ until all four artifacts of one vintage are in hand, and
# the publish is a directory rename rather than four file copies. On a crash between the two
# renames the previous generation is still on disk as prior-artifacts.previous/.

STAGE=""
cleanup_stage() { if [[ -n "$STAGE" && -d "$STAGE" ]]; then rm -rf "$STAGE"; fi; }
trap cleanup_stage EXIT

save_one() {  # save_one <artifact file>
    local f="$1"
    if [[ -f "target/$f" ]]; then
        cp "target/$f" "$STAGE/$f"
    else
        echo "  ! target/$f was not produced by the command that owns it" >&2
        return 1
    fi
}

run_and_capture() {
    STAGE="$(mktemp -d)"

    echo "==> $DBT build"
    rm -f target/manifest.json target/run_results.json
    "$DBT" build >/dev/null
    save_one manifest.json
    save_one run_results.json      # captured HERE, before anything else clobbers it

    echo "==> $DBT source freshness"
    rm -f target/sources.json
    local rc=0
    "$DBT" source freshness >/dev/null || rc=$?
    # Exit 1 can mean stale data OR a failed query. Core 1.11.14 can omit failed sources
    # from sources.json, so validate completeness as well as the returned statuses.
    if [[ "$rc" != 0 && "$rc" != 1 ]]; then
        echo "  ! dbt source freshness exited $rc, which is not a staleness verdict" >&2
        return 1
    fi
    save_one sources.json
    "$PYTHON" - "$STAGE/manifest.json" "$STAGE/sources.json" "$rc" <<'PY'
import json
import sys
from pathlib import Path

try:
    manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    artifact = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    expected = {
        uid for uid, source in manifest["sources"].items()
        if source.get("config", {}).get("enabled", True)
        and any(threshold.get("count") is not None and threshold.get("period") is not None
                for key in ("warn_after", "error_after")
                for threshold in [((source.get("freshness") or {}).get(key) or {})])
    }
    results = artifact["results"]
    ids = [result["unique_id"] for result in results]
    statuses = [result["status"] for result in results]
    if len(ids) != len(set(ids)) or set(ids) != expected:
        raise ValueError("freshness source inventory differs: missing=%s unexpected=%s"
                         % (sorted(expected - set(ids)), sorted(set(ids) - expected)))
    if any(status not in {"pass", "warn", "error"} for status in statuses):
        raise ValueError("freshness contains a non-verdict result")
    if sys.argv[3] == "1" and "error" not in statuses:
        raise ValueError("freshness exited 1 without a complete stale-data verdict")
except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
    sys.exit("  ! refusing incomplete freshness baseline: %s" % exc)
print("  validated freshness verdicts for %d source(s)" % len(ids))
PY

    echo "==> $DBT docs generate"
    rm -f target/catalog.json
    "$DBT" docs generate >/dev/null
    save_one catalog.json

    publish_stage
}

publish_stage() {
    local incoming="prior-artifacts.incoming" previous="prior-artifacts.previous"
    rm -rf "$incoming" "$previous"
    mkdir -p "$incoming"
    cp "$STAGE"/*.json "$incoming"/
    if [[ -d prior-artifacts ]]; then mv prior-artifacts "$previous"; fi
    mv "$incoming" prior-artifacts
    rm -rf "$previous"
    echo "==> published one complete artifact generation to prior-artifacts/"
}

# ---------------------------------------------------------------- snapshot mode

if [[ "$MODE" == "snapshot" ]]; then
    run_and_capture
    echo
    echo "Baseline saved from the CURRENT project state."
    echo "state:modified will select nothing until you change something."
    ls -la prior-artifacts/*.json
    exit 0
fi

# ---------------------------------------------------------------- rebase mode

[[ -f "$PREIMAGE_DIR/PREIMAGE" ]] || {
    echo "$PREIMAGE_DIR/PREIMAGE not found." >&2; exit 1; }

STASH="$(mktemp -d)"
RESTORE_LIST="$STASH/.restore"
: > "$RESTORE_LIST"

restore() {
    local rc=$?
    cleanup_stage        # this trap REPLACES the staging trap installed above; do both jobs
    if [[ -s "$RESTORE_LIST" ]]; then
        echo "==> restoring working tree"
        while IFS= read -r p; do
            mkdir -p "$(dirname "$p")"
            cp "$STASH/blobs/$(echo "$p" | tr '/' '_')" "$p"
        done < "$RESTORE_LIST"
    fi
    rm -rf "$STASH"
    exit $rc
}
trap restore EXIT INT TERM

mkdir -p "$STASH/blobs"

# Stage the preimage, verifying each HEAD file against its recorded hash first.
while IFS=$'\t' read -r mode path want; do
    [[ -z "${mode:-}" || "${mode:0:1}" == "#" ]] && continue
    [[ -f "$path" ]] || { echo "PREIMAGE lists '$path', which does not exist." >&2; exit 1; }
    got="$(sha256sum "$path" | cut -d' ' -f1)"
    if [[ "$got" != "$want" ]]; then
        cat >&2 <<EOF
Preimage drift: $path has changed since the baseline preimage was derived.
  recorded: $want
  actual:   $got
Re-derive the preimage before rebasing -- see $PREIMAGE_DIR/README.md ("Maintaining it").
EOF
        exit 1
    fi
    cp "$path" "$STASH/blobs/$(echo "$path" | tr '/' '_')"
    echo "$path" >> "$RESTORE_LIST"
    case "$mode" in
        replace) echo "==> staging preimage: $path"; cp "$PREIMAGE_DIR/files/$path" "$path" ;;
        remove)  echo "==> removing for baseline: $path"; rm -f "$path" ;;
        *)       echo "unknown PREIMAGE mode '$mode'" >&2; exit 1 ;;
    esac
done < "$PREIMAGE_DIR/PREIMAGE"

run_and_capture

echo
echo "Baseline rebuilt from the preimage. The working tree is restored on exit."
echo "Verify with:"
echo "  $DBT ls --select state:modified  --state ./prior-artifacts --resource-type model"
echo "  $DBT ls --select state:new       --state ./prior-artifacts"
echo "  bash scripts/slim-ci.sh"
