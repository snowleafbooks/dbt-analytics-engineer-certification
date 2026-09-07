#!/usr/bin/env bash
# `enabled: false` check, on models/marts/_example_disabled.sql.
#
# Two preconditions -- the project parses, and `dbt ls` returns a DAG -- and then the claim,
# which is the part worth reading. Both preconditions exist because this check reads artifacts
# rather than errors, and artifacts stay quiet: a dead environment produces an empty `dbt ls`
# and a stale manifest, and every assertion below passes vacuously against them.
#
# The claim: a disabled node is NOT absent.
# it is parsed, and parked in manifest['disabled'] rather than manifest['nodes']. No
# selector can reach it -- `dbt ls --select _example_disabled` prints exactly what it prints
# for a name that never existed -- so the manifest is the only place the distinction between
# "disabled" and "does not exist" survives. That is where to look when a model has vanished
# from a build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DBT="${DBT:-dbt}"
PYTHON="${PYTHON:-python}"
export DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-$HOME/.dbt}"

NODE=model.dbtae_companion._example_disabled
fail=0

# Hard gate, and it has to come first. Every assertion below reads either `dbt ls` output or
# target/manifest.json, and both go quiet rather than loud when dbt cannot run: an empty
# `dbt ls` makes "absent from dbt ls" vacuously true, and a manifest left behind by an earlier
# good run answers the manifest probe for a project that no longer parses. A dead environment
# would otherwise collect three `ok`s. So parse once, here, and stop if it fails.
echo "--- precondition: the project parses ---"
if ! "$DBT" parse >/dev/null 2>&1; then
    echo "  FAIL dbt parse failed -- nothing below can be trusted."
    echo "       Run '$DBT parse' to see why; target/manifest.json may be stale from an earlier run."
    exit 1
fi
echo "  ok   parsed; target/manifest.json is current"

echo ""
echo "--- models in the DAG ---"
# `|| true` here absorbs grep's exit 1 on no-match only -- dbt's own health is already settled
# by the gate above, and the count is asserted non-zero rather than printed and trusted.
n=$("$DBT" ls --resource-type model 2>/dev/null | grep -c '^dbtae_companion' || true)
echo "  $n"
if [ "$n" -gt 0 ]; then
    echo "  ok   dbt ls returned a DAG, so 'absent' below means absent and not empty"
else
    echo "  FAIL dbt ls listed no models at all"
    fail=1
fi

echo ""
echo "--- _example_disabled must not appear in dbt ls ---"
if "$DBT" ls --resource-type model 2>/dev/null | grep -qi '_example_disabled'; then
    echo "  FAIL it is listed; the node is not disabled"
    fail=1
else
    echo "  ok   absent from dbt ls"
fi

echo ""
echo "--- but it IS in the manifest, under 'disabled' ---"
# No parse here: the gate at the top already wrote this manifest, and swallowing a failure at
# this point is what let a stale artifact answer for a broken project.
verdict=$("$PYTHON" - "$NODE" <<'PY'
import json, sys
node = sys.argv[1]
m = json.load(open("target/manifest.json"))
in_nodes = node in m["nodes"]
in_disabled = node in m.get("disabled", {})
print("nodes=%s disabled=%s" % (in_nodes, in_disabled))
PY
)
echo "  $verdict"
if [ "$verdict" = "nodes=False disabled=True" ]; then
    echo "  ok   parsed, then parked in manifest['disabled'] -- not missing, unreachable"
else
    echo "  FAIL expected 'nodes=False disabled=True'"
    fail=1
fi

echo ""
echo "--- why the manifest is the only tell: dbt ls cannot distinguish the two ---"
echo "  disabled name:"
"$DBT" ls --select _example_disabled 2>&1 | tail -1 | sed 's/^/    /'
echo "  name that never existed:"
"$DBT" ls --select i_do_not_exist_at_all 2>&1 | tail -1 | sed 's/^/    /'

exit $fail
