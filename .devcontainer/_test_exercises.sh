#!/usr/bin/env bash
#
# Exercise suite. Stages each fixture in exercises/ into the project, runs its trigger
# command, and asserts three things per case:
#
#   1. the EXIT CODE the command returns,
#   2. the LAYER dbt stopped at (parse / compile / run), established by probing,
#   3. a REGEX drawn from the error dbt actually emits.
#
# All three matter. A regex alone is not an assertion: a case name echoed inside an
# unrelated error's file list will satisfy it while the fixture teaches nothing. The
# regex here is matched against the output with every `_tmp_broken` path token stripped,
# so a filename can never stand in for a message.
#
# Layer is derived, not declared: `dbt parse` is probed first; if it survives, `dbt
# compile` is probed; whatever is left is the run layer. That is what pins a case to a
# layer — when dbt moves an error earlier or later between releases, the suite says so
# instead of passing quietly.
#
# Five cases cannot be asserted that way, because dbt prints nothing worth matching: the
# lesson is an edge dbt did not record, a graph that changed under a `--vars`, a key that
# never reached the manifest, or a deprecation that is only a failure once you promote it.
# They get their own helpers — `run_dag_case`, `run_conditional_ref_case`,
# `run_silent_case`, `run_deprecation_case` — and each asserts the artifact instead of the
# console. Asserting the console on any of them would record a PASS for silence.
#
# Usage
#   bash .devcontainer/_test_exercises.sh            # whole suite
#   bash .devcontainer/_test_exercises.sh cyclic ref_typo   # named cases only
#
# Environment
#   DBT         dbt executable (default: dbt)
#   DBT_TARGET  profile target to use (default: the profile's own default)
#   PYTHON      python executable used for the manifest probe (default: python)
set -uo pipefail

# Project root, resolved from this script's own location, so the suite runs the same
# from the devcontainer (/workspaces/...) and from a clone anywhere on disk.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DBT="${DBT:-dbt}"
PYTHON="${PYTHON:-python}"
export DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-$HOME/.dbt}"
# Only run_compiled_sql_case needs this: it is the single case that builds into the warehouse,
# and it drops what it built afterwards. Same convention as the other verifiers here.
PSQL="${PSQL:-psql -h ${POSTGRES_HOST:-postgres} -p ${POSTGRES_PORT:-5432}}"

TARGET_ARGS=()
if [ -n "${DBT_TARGET:-}" ]; then
    TARGET_ARGS=(--target "$DBT_TARGET")
fi

TMP=models/_tmp_broken
MTMP=macros/_tmp_broken

pass=0
fail=0
declare -a failures=()
declare -a only=("$@")
declare -A recognized=()

# Staging dirs are removed however this script ends. INT and TERM are trapped explicitly, not
# left to the EXIT trap: a fixture abandoned in models/_tmp_broken/ is not in .gitignore, and
# it breaks the next `dbt build` for a reader who has forgotten it is there.
cleanup() { rm -rf "$TMP" "$MTMP"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

selected() {
    recognized["$1"]=1
    [ ${#only[@]} -eq 0 ] && return 0
    local c
    for c in "${only[@]}"; do [ "$c" = "$1" ] && return 0; done
    return 1
}

# Stage one case. Every regular file in exercises/<case>/ except its README lands in
# models/_tmp_broken/; anything in exercises/<case>/macros/ lands in macros/_tmp_broken/.
# This is the exact flow exercises/README.md tells a reader to run by hand.
stage() {
    local name="$1"
    rm -rf "$TMP" "$MTMP"
    mkdir -p "$TMP"
    find "exercises/$name" -maxdepth 1 -type f ! -name README.md -exec cp {} "$TMP/" \;
    if [ -d "exercises/$name/macros" ]; then
        mkdir -p "$MTMP"
        cp "exercises/$name/macros/"*.sql "$MTMP/"
    fi
}

# Strip ANSI colour and every path token containing _tmp_broken, so the regex can only
# match dbt's message text — never the fixture's own filename.
sanitize() {
    sed -e 's/\x1b\[[0-9;]*m//g' -e 's/[^[:space:]]*_tmp_broken[^[:space:]]*//g'
}

dbt_rc() {  # run dbt quietly, return its exit code
    "$DBT" "$@" "${TARGET_ARGS[@]}" --no-partial-parse >/dev/null 2>&1
}

# Derive the layer at which this fixture stops dbt.
#   parse   -> `dbt parse` fails
#   compile -> `dbt parse` succeeds, `dbt compile` fails
#   run     -> both succeed; only building the node fails
observed_layer() {
    local sel="$1"
    if ! dbt_rc parse; then echo parse; return; fi
    if [ -n "$sel" ]; then
        dbt_rc compile --select "$sel" || { echo compile; return; }
    else
        dbt_rc compile || { echo compile; return; }
    fi
    echo run
}

report() {
    local ok="$1" name="$2" detail="$3"
    if [ "$ok" = yes ]; then
        printf 'PASS  [%s]  %s\n' "$name" "$detail"
        pass=$((pass + 1))
    else
        printf 'FAIL  [%s]  %s\n' "$name" "$detail"
        failures+=("$name")
        fail=$((fail + 1))
    fi
}

# run_case <name> <expect_exit> <expect_layer> <probe_select> <regex> -- <command...>
run_case() {
    local name="$1" want_exit="$2" want_layer="$3" probe_sel="$4" regex="$5"
    shift 6  # drop the five fields and the literal --
    local cmd=("$@")

    selected "$name" || return 0
    stage "$name"

    local out rc layer
    out=$("${cmd[@]}" "${TARGET_ARGS[@]}" --no-partial-parse 2>&1)
    rc=$?
    layer=$(observed_layer "$probe_sel")

    local -a problems=()
    [ "$rc" = "$want_exit" ] || problems+=("exit $rc (want $want_exit)")
    [ "$layer" = "$want_layer" ] || problems+=("layer $layer (want $want_layer)")
    printf '%s\n' "$out" | sanitize | grep -qE "$regex" || problems+=("no match for /$regex/")

    if [ ${#problems[@]} -eq 0 ]; then
        report yes "$name" "exit $rc, $layer layer, matched /$regex/"
    else
        report no "$name" "$(printf "%s; " "${problems[@]}")"
        printf '%s\n' "$out" | sanitize | tail -8 | sed 's/^/        /'
    fi

    rm -rf "$TMP" "$MTMP"
}

# A case whose lesson is that dbt says NOTHING. Asserts a clean exit and that the
# offending key never reaches the manifest — the only evidence that survives.
run_silent_case() {
    local name="$1" node="$2" key="$3"

    selected "$name" || return 0
    stage "$name"

    local out rc
    out=$("$DBT" parse "${TARGET_ARGS[@]}" --no-partial-parse 2>&1)
    rc=$?

    local -a problems=()
    [ "$rc" = 0 ] || problems+=("exit $rc (want 0 — dbt is expected to accept this silently)")
    printf '%s\n' "$out" | sanitize | grep -qiE "$key" && problems+=("dbt mentioned '$key'; this case is documented as silent — re-check the adapter gate")

    local probe
    probe=$("$PYTHON" -c "
import json, sys
m = json.load(open('target/manifest.json'))
n = m['nodes'].get('$node')
print('missing-node' if n is None else ('key-present' if '$key' in n else 'ok'))
" 2>&1)
    [ "$probe" = ok ] || problems+=("manifest probe: $probe")

    if [ ${#problems[@]} -eq 0 ]; then
        report yes "$name" "exit 0, no diagnostic, '$key' absent from the manifest"
    else
        report no "$name" "$(printf "%s; " "${problems[@]}")"
    fi

    rm -rf "$TMP" "$MTMP"
}

# Read the recorded parent edges of one or more model nodes straight out of the manifest, in
# the exact `node:parent[,parent]` shape the expectation is written in, `-` for no parents.
# The manifest is the only honest place to ask this: `dbt ls --select +node` answers it too,
# but its output is a path token that sanitize() strips, and console text cannot distinguish
# "dbt recorded no edge" from "dbt recorded the edge and the run happened to work anyway".
manifest_edges() {
    "$PYTHON" -c "
import json, sys
m = json.load(open('target/manifest.json'))
out = []
for pair in sys.argv[1:]:
    name = pair.split(':', 1)[0]
    node = m['nodes'].get('model.dbtae_companion.' + name)
    if node is None:
        out.append(name + ':MISSING-NODE')
        continue
    parents = sorted(p.split('.')[-1] for p in node['depends_on']['nodes'])
    out.append(name + ':' + (','.join(parents) if parents else '-'))
print(' '.join(out))
" "$@"
}

# A case whose lesson is a GRAPH FACT — which edges dbt recorded and which it did not. Warehouse
# state cannot perturb a manifest, so this assertion holds on a schema where the parent happens
# to exist from an earlier session, which is exactly when the console goes quiet and misleads.
# Where the missing edge also has a visible run-time consequence, the command asserts that too.
#
# run_dag_case <name> <want_exit> <regex|-> <expect_edges> -- <command...>
#   expect_edges: "node:parent,parent node2:-"  (parent short names, sorted)
# A case whose lesson is a SILENT DEGRADATION at run time: dbt exits 0, warns about nothing,
# and the only evidence is in the compiled SQL under target/. run_silent_case probes the
# manifest, which cannot see this -- the fault is in what the adapter macro generated, not in
# what was parsed. Runs the model TWICE, because the first run is a full build and only the
# second takes the incremental path being tested.
run_compiled_sql_case() {
    local name="$1" want_present="$2" want_absent="$3"

    selected "$name" || return 0
    stage "$name"

    local -a problems=()
    local out rc

    # --select THE FIXTURE. Unselected, these two lines rebuild the entire project -- measured,
    # 2026-09-06: the second run reported 21 results, the fixture plus 18 ordinary models and the
    # two project hooks -- which is slow, writes the reader's dev schema from a script documented
    # as not touching the warehouse, and buries this case's own result in the noise.
    out=$("$DBT" run "${TARGET_ARGS[@]}" --select "$name" --full-refresh --no-partial-parse 2>&1); rc=$?
    [ "$rc" = 0 ] || problems+=("full-refresh run exited $rc (want 0)")
    out=$("$DBT" run "${TARGET_ARGS[@]}" --select "$name" --no-partial-parse 2>&1); rc=$?
    [ "$rc" = 0 ] || problems+=("incremental run exited $rc (want 0 -- dbt accepts this silently)")
    # Match a real diagnostic, not the fixture's own name: the model is called
    # merge_no_unique_key, so grepping the output for 'unique_key' matches the node line
    # dbt prints for every successful model. WARN=[1-9] and the word Warning are the
    # signals that mean dbt actually said something.
    # Scope the silence assertion to THIS FIXTURE. Two traps here, both hit while writing it:
    # the model is called merge_no_unique_key, so grepping for 'unique_key' matches the node
    # line dbt prints for every success; and the project already emits an unrelated
    # deprecation WARNING about dim_customer_segments.v1 on every run, which is nothing to do
    # with this case. What must be silent is dbt's opinion of THIS model.
    printf '%s
' "$out" | sanitize | grep -qE 'WARN=[1-9]'         && problems+=("the run summary reports WARN>0; this case is documented as silent")
    printf '%s
' "$out" | sanitize | grep -E '\[WARNING\]|Warning:'         | grep -q "$name"         && problems+=("dbt warned about $name itself; this case is documented as silent")

    local sql
    sql=$(cat target/run/dbtae_companion/models/_tmp_broken/${name}.sql 2>/dev/null           || cat target/compiled/dbtae_companion/models/_tmp_broken/${name}.sql 2>/dev/null)
    if [ -z "$sql" ]; then
        problems+=("no compiled SQL under target/ -- the only evidence this case has")
    else
        printf '%s
' "$sql" | grep -qiE "$want_present"             || problems+=("compiled SQL has no match for /$want_present/")
        printf '%s
' "$sql" | grep -qiE "$want_absent"             && problems+=("compiled SQL DOES contain /$want_absent/ -- the degradation did not happen, so this fixture teaches nothing")
    fi

    if [ ${#problems[@]} -eq 0 ]; then
        report yes "$name" "exit 0 twice, no diagnostic, compiled SQL matched /$want_present/ and carried no /$want_absent/"
    else
        report no "$name" "$(printf "%s; " "${problems[@]}")"
    fi

    # This is the ONE case in the suite that reaches the warehouse -- it has to, because the
    # degradation it teaches is only visible after a second incremental run. Take the relation
    # back out, so the suite leaves the schema as it found it. Without this the fixture stays
    # behind carrying the duplicate rows that are the whole point of the case, and the next
    # reader finds a table nothing in the project declares.
    drop_fixture_relation "$name"

    rm -rf "$TMP" "$MTMP"
}

# Remove a relation a fixture built. Uses the same $PSQL convention as the other verifiers in
# this directory; says so and moves on when no client is reachable, rather than failing a case
# on the cleanup.
drop_fixture_relation() {
    local name="$1"
    if ! command -v ${PSQL%% *} >/dev/null 2>&1; then
        echo "      note: no psql on PATH -- ${DBT_SCHEMA:-dev}.$name left in the warehouse"
        return 0
    fi
    PGPASSWORD="${POSTGRES_PASSWORD:-dbt_developer_pw}"         $PSQL -U "${POSTGRES_USER:-dbt_developer}" -d "${POSTGRES_DB:-dbtae}"         -c "drop table if exists \"${DBT_SCHEMA:-dev}\".\"$name\" cascade" >/dev/null 2>&1         || echo "      note: could not drop ${DBT_SCHEMA:-dev}.$name"
}

run_dag_case() {
    local name="$1" want_exit="$2" regex="$3" expect_edges="$4"
    shift 5  # drop the four fields and the literal --
    local cmd=("$@")

    selected "$name" || return 0
    stage "$name"

    local -a problems=()

    # Parse first, so the graph read below is the fixture's own and not a leftover manifest
    # from whatever the command did or failed to do.
    if ! dbt_rc parse; then
        problems+=("the fixture does not parse, so no graph could be read")
    fi

    local out rc edges
    out=$("${cmd[@]}" "${TARGET_ARGS[@]}" --no-partial-parse 2>&1)
    rc=$?
    [ "$rc" = "$want_exit" ] || problems+=("exit $rc (want $want_exit)")
    if [ "$regex" != "-" ]; then
        printf '%s\n' "$out" | sanitize | grep -qE "$regex" || problems+=("no match for /$regex/")
    fi

    edges=$(manifest_edges $expect_edges)
    [ "$edges" = "$expect_edges" ] || problems+=("edges [$edges] (want [$expect_edges])")

    if [ ${#problems[@]} -eq 0 ]; then
        report yes "$name" "exit $rc, edges [$edges]"
    else
        report no "$name" "$(printf "%s; " "${problems[@]}")"
        printf '%s\n' "$out" | sanitize | tail -8 | sed 's/^/        /'
    fi

    rm -rf "$TMP" "$MTMP"
}

# One file, parsed twice, with two different sets of parents. There is no error and no exit code
# to assert here — the lesson is that the graph is a function of parse-time context, so the only
# assertion that says anything is two manifests that disagree.
#
# run_conditional_ref_case <name> <node> <vars-json> <expect_default> <expect_with_vars>
run_conditional_ref_case() {
    local name="$1" node="$2" vars="$3" want_default="$4" want_vars="$5"

    selected "$name" || return 0
    stage "$name"

    local -a problems=()
    local got_default got_vars

    "$DBT" parse "${TARGET_ARGS[@]}" --no-partial-parse >/dev/null 2>&1 \
        || problems+=("default parse failed")
    got_default=$(manifest_edges "$node:")

    "$DBT" parse "${TARGET_ARGS[@]}" --no-partial-parse --vars "$vars" >/dev/null 2>&1 \
        || problems+=("parse with --vars '$vars' failed")
    got_vars=$(manifest_edges "$node:")

    [ "$got_default" = "$node:$want_default" ] || problems+=("default edges [$got_default] (want [$node:$want_default])")
    [ "$got_vars" = "$node:$want_vars" ] || problems+=("--vars edges [$got_vars] (want [$node:$want_vars])")
    [ "$want_default" = "$want_vars" ] && problems+=("the two expectations are identical, so this case asserts nothing")

    if [ ${#problems[@]} -eq 0 ]; then
        report yes "$name" "same file, two graphs: [$got_default] then [$got_vars] under --vars '$vars'"
    else
        report no "$name" "$(printf "%s; " "${problems[@]}")"
    fi

    rm -rf "$TMP" "$MTMP"
}

# A case with THREE halves, and asserting only the first records the opposite of the lesson.
# Half one: dbt accepts the file today and emits <deprecation>. Half two: the deprecated
# spelling STILL TAKES EFFECT — the config reaches the manifest, which is the only place that
# can be asked. Half three: the same parse with that one deprecation promoted to an error is a
# hard failure. "dbt allows this", "and it still works" and "this is one flag away from failing
# your build" are one fact, and a suite that checks only the clean exit reports the reassuring
# third of it.
#
# The manifest probe is what makes REPO-COVERAGE.md's claim that this case is asserted
# "against the config the manifest actually records" true. Without it that claim was prose,
# and the half a reader is likeliest to get wrong in both directions was the unasserted one.
#
# run_deprecation_case <name> <deprecation> <regex> <node_name> <config_key> <config_value>
run_deprecation_case() {
    local name="$1" dep="$2" regex="$3" node="$4" ckey="$5" cval="$6"

    selected "$name" || return 0
    stage "$name"

    local out rc strict_out strict_rc applied
    out=$("$DBT" parse "${TARGET_ARGS[@]}" --no-partial-parse 2>&1)
    rc=$?

    # Read the manifest the PLAIN parse wrote, and read it BEFORE the strict parse runs: that
    # one is expected to fail, and a failed parse leaves whatever manifest was there before it.
    applied=$("$PYTHON" -c "
import json
m = json.load(open('target/manifest.json'))
hits = [n for n in m['nodes'].values() if n.get('name') == '$node']
if not hits:
    print('missing-node')
else:
    got = hits[0].get('config', {}).get('$ckey')
    print('ok' if str(got) == '$cval' else 'config $ckey=' + repr(got))
" 2>&1)

    strict_out=$("$DBT" parse "${TARGET_ARGS[@]}" --no-partial-parse \
        --warn-error-options "{\"error\": [\"$dep\"]}" 2>&1)
    strict_rc=$?

    local -a problems=()
    [ "$rc" = 0 ] || problems+=("plain parse exited $rc (want 0 — dbt is expected to accept this today)")
    printf '%s\n' "$out" | sanitize | grep -qE "$dep" \
        || problems+=("plain parse never mentioned $dep")
    [ "$applied" = ok ] || problems+=("the deprecated spelling did not reach the manifest: $applied (want $ckey=$cval on $node)")
    [ "$strict_rc" = 2 ] || problems+=("parse with $dep promoted to an error exited $strict_rc (want 2)")
    printf '%s\n' "$strict_out" | sanitize | grep -qE "$regex" \
        || problems+=("no match for /$regex/ under --warn-error-options")

    if [ ${#problems[@]} -eq 0 ]; then
        report yes "$name" "exit 0 with $dep, $ckey=$cval still recorded in the manifest; exit 2 once that deprecation is promoted to an error"
    else
        report no "$name" "$(printf "%s; " "${problems[@]}")"
        printf '%s\n' "$strict_out" | sanitize | tail -8 | sed 's/^/        /'
    fi

    rm -rf "$TMP" "$MTMP"
}

echo "=== Exercise suite ==="
echo "    root:   $ROOT"
echo "    dbt:    $("$DBT" --version 2>/dev/null | sed -n 's/.*installed: *//p' | head -1)"
echo "    target: ${DBT_TARGET:-<profile default>}"
echo ""

# Precondition, and it earns the five seconds. Every fixture below is staged into a project
# that has to be healthy otherwise, and the commonest first-run mistake -- forgetting
# `dbt deps` -- makes every case fail on a packages error while the suite reports each
# case's own regex and a nonsense layer. That is two minutes of runtime pointing at the wrong
# thing. Parse the clean project once, and if it will not parse, say what actually broke.
echo "--- precondition: the clean project parses ---"
rm -rf "$TMP" "$MTMP"
pre_out=$("$DBT" parse "${TARGET_ARGS[@]}" --no-partial-parse 2>&1)
pre_rc=$?
if [ "$pre_rc" != 0 ]; then
    echo "FAIL  the project does not parse before any fixture is staged (exit $pre_rc)." >&2
    printf '%s\n' "$pre_out" | sanitize | tail -8 | sed 's/^/        /' >&2
    if printf '%s\n' "$pre_out" | grep -q 'package(s) installed'; then
        echo "" >&2
        echo "      Run \`dbt deps\` first: packages.yml is declared but dbt_packages/ is empty." >&2
    fi
    exit 1
fi
echo "  ok   clean project parses; every failure below is the fixture's own"
echo ""

#         case                          exit layer    compile-probe select            regex                                                                          --  command
run_case  cyclic                        2    compile  ""                              'Found a cycle: model\.dbtae_companion\.A --> model\.dbtae_companion\.B'         -- "$DBT" compile
run_case  ref_typo                      2    parse    ""                              "depends on a node named 'stg_orderz' which was not found"                      -- "$DBT" parse
run_case  ref_disabled                  2    parse    ""                              "depends on a node named 'disabled_target' which is disabled"                   -- "$DBT" parse
run_case  ref_bad_version               2    parse    ""                              "depends on a node named 'dim_customer_segments' with version '99'"             -- "$DBT" parse
run_case  access_violation              2    parse    ""                              "not allowed because the referenced node is private to the 'pii' group"         -- "$DBT" parse
run_case  public_ephemeral              2    parse    ""                              "with 'ephemeral' materialization has an invalid value \(public\) for the access field" -- "$DBT" parse
run_case  macro_arity                   2    parse    ""                              "takes no keyword argument 'precision_level'"                                   -- "$DBT" parse
run_case  dispatch_miss                 2    parse    ""                              "In dispatch: No macro named 'i_am_not_implemented' found"                      -- "$DBT" parse
run_case  jinja_unbalanced              2    parse    ""                              "Unexpected end of template"                                                    -- "$DBT" parse
run_case  yaml_indent                   2    parse    ""                              "did not find expected '-' indicator"                                           -- "$DBT" parse
run_case  yaml_wrong_type               2    parse    ""                              "at path \['materialized'\]: True is not of type 'string'"                      -- "$DBT" parse
run_case  macro_undefined               2    compile  macro_undefined                 "'generate_surrogate_key' is undefined"                                         -- "$DBT" compile --select macro_undefined
run_case  contract_drift                1    run      contract_drift                  'This model has an enforced contract that failed'                               -- "$DBT" run --select contract_drift
run_case  constraint_missing_data_type  1    run      constraint_missing_data_type    'Contracted models require data_type to be defined for each column'              -- "$DBT" run --select constraint_missing_data_type
run_case  source_misresolved            1    run      stg_orders_misresolved          'relation "ecom_landing\.orders" does not exist'                                 -- "$DBT" run --select stg_orders_misresolved

run_case  unquoted_macro_arg            1    run      unquoted_macro_arg              'round\(cast\( as numeric\)'                                                    -- "$DBT" run --select unquoted_macro_arg

# The last five fail no layer, or fail one for a reason the console does not name. Their
# assertions are the manifest and a promoted deprecation, not an error message -- see the
# helper comments above for why a console regex would pass over every one of them.
run_dag_case  hardcoded_relation  1  'relation "[^"]*\.hc_upstream" does not exist'  "orders_hardcoded:- hc_upstream:-"                        -- "$DBT" run --select orders_hardcoded
run_dag_case  depends_on_comment  0  -                                               "orders_via_sql_comment:dc_upstream orders_via_jinja_comment:-"  -- "$DBT" parse

run_conditional_ref_case conditional_ref conditional_ref '{use_products: true}' stg_orders stg_products

run_deprecation_case test_config_not_nested PropertyMovedToConfigDeprecation 'Invalid generic test configuration given in' not_null_test_config_model_order_id severity warn

run_silent_case yaml_unknown_key model.dbtae_companion.unknown_key_model frobulate
run_compiled_sql_case merge_no_unique_key 'on \(FALSE\)' 'when matched'

# Validate against the handlers above, so the case registry has only one home.
for name in "${only[@]}"; do
    if [[ -z "$name" || -z "${recognized[$name]:-}" ]]; then
        report no "$name" "unknown exercise name; no fixture was run for this request"
    fi
done

echo ""
echo "=== Summary: $pass PASS / $fail FAIL ==="
if ((fail > 0)); then
    echo "Failures: ${failures[*]}"
    exit 1
fi
