#!/usr/bin/env bash
# Exercise each broken example. Expects each to produce an error; reports PASS/FAIL per example.
set -uo pipefail

cd /workspaces/dbt-analytics-engineer-certification
export DBT_PROFILES_DIR=/home/vscode/.dbt

TMP=models/_tmp_broken
MTMP=macros/_tmp_broken

pass=0
fail=0
declare -a failures=()

trap 'rm -rf "$TMP" "$MTMP"' EXIT

run_case() {
    local name="$1"
    local expected="$2"
    shift 2
    local cmd=("$@")

    rm -rf "$TMP" "$MTMP"
    mkdir -p "$TMP"

    case "$name" in
      cyclic)
        cp exercises/cyclic/A.sql exercises/cyclic/B.sql "$TMP/" ;;
      ref_typo)
        cp exercises/ref_typo/ref_typo.sql "$TMP/" ;;
      ref_disabled)
        cp exercises/ref_disabled/disabled_target.sql exercises/ref_disabled/consumer_of_disabled.sql "$TMP/" ;;
      ref_bad_version)
        cp exercises/ref_bad_version/ref_bad_version.sql "$TMP/" ;;
      contract_drift)
        cp exercises/contract_drift/contract_drift.sql exercises/contract_drift/_contract_drift.yml "$TMP/" ;;
      access_violation)
        cp exercises/access_violation/cross_group_consumer.sql "$TMP/" ;;
      public_ephemeral)
        cp exercises/public_ephemeral/public_ephemeral.sql "$TMP/" ;;
      macro_undefined)
        cp exercises/macro_undefined/macro_undefined.sql "$TMP/" ;;
      macro_arity)
        cp exercises/macro_arity/macro_arity.sql "$TMP/" ;;
      dispatch_miss)
        mkdir -p "$MTMP"
        cp exercises/dispatch_miss/dispatch_miss.sql "$TMP/"
        cp exercises/dispatch_miss/_macro.sql "$MTMP/" ;;
      jinja_unbalanced)
        cp exercises/jinja_unbalanced/jinja_unbalanced.sql "$TMP/" ;;
      yaml_indent)
        cp exercises/yaml/indent.yml.broken "models/_tmp_broken/_indent.yml" ;;
      yaml_wrong_type)
        cp exercises/yaml/wrong_type.yml.broken "models/_tmp_broken/_wrong_type.yml" ;;
      yaml_unknown_key)
        cp exercises/yaml/unknown_key.yml.broken "models/_tmp_broken/_unknown_key.yml" ;;
    esac

    local output
    output=$("${cmd[@]}" 2>&1 || true)

    if echo "$output" | grep -qiE "$expected"; then
        echo "PASS  [$name]  matched: $expected"
        ((pass++))
    else
        echo "FAIL  [$name]  expected pattern: $expected"
        echo "      last 6 lines of output:"
        echo "$output" | tail -6 | sed 's/^/        /'
        failures+=("$name")
        ((fail++))
    fi

    rm -rf "$TMP" "$MTMP"
}

echo "=== Exercise suite ==="

run_case cyclic            "cycle|Cycl"                    dbt compile
run_case ref_typo          "not.?found|stg_orderz"         dbt parse
run_case ref_disabled      "disabled"                      dbt parse
run_case ref_bad_version   "version"                       dbt parse
run_case contract_drift    "columns|contract|schema"       dbt run --select contract_drift
run_case access_violation  "private|access|group"          dbt parse
run_case public_ephemeral  "ephemeral|public"              dbt parse
run_case macro_undefined   "undefined|generate_surrogate"  dbt compile --select macro_undefined
run_case macro_arity       "unexpected|argument|keyword"   dbt compile --select macro_arity
run_case dispatch_miss     "dispatch|not.?found|No macro"  dbt compile --select dispatch_miss
run_case jinja_unbalanced  "endif|Unexpected|Jinja"        dbt parse
run_case yaml_indent       "yaml|YAML|mapping|indentation|block mapping|did not find expected|indicator" dbt parse
run_case yaml_wrong_type   "yaml|YAML|invalid|boolean|true|duplicate|two schema|same resource"         dbt parse
run_case yaml_unknown_key  "frobulate|unknown|Unexpected|additional"    dbt parse

echo ""
echo "=== Summary: $pass PASS / $fail FAIL ==="
if ((fail > 0)); then
    echo "Failures: ${failures[*]}"
    exit 1
fi
