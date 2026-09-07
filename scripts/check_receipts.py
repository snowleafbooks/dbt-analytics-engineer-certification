#!/usr/bin/env python
"""Re-measure every build receipt this repo prints in prose, and diff it against the prose.

WHY THIS EXISTS

    The same summary line is quoted in README.md, REPO-COVERAGE.md, RELEASE-NOTES-1.11.md, the
    build badge, and a model description. On 2026-09-06 all of them still read
    `PASS=116 ... TOTAL=119` and `21 exercises`; the project had been building
    `PASS=117 ... TOTAL=120` and shipping 22 exercises for some time. Nothing was watching, so
    nothing said so. A number a reader can check in one command has to be checked by one command.

WHAT IT DOES NOT DO

    It does not rewrite prose, and it does not judge whether a receipt is a good thing to quote.
    It runs the commands, then asserts that everything they now print is still findable in the
    prose -- see the note above MEASURED_COMMANDS for why the comparison runs in that direction
    and not the other one.

EVERY RULE REPORTS WHAT IT BOUND, and a rule that matched nothing FAILS rather than passing. A
check that silently watches zero lines is worse than no check, because it reads as evidence.

    python scripts/check_receipts.py            # measure and compare
    python scripts/check_receipts.py --offline  # skip the dbt runs; only the countable rules

Environment: DBT (default: dbt), plus whatever the profile needs to reach the warehouse.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DBT = os.environ.get("DBT", "dbt")

DOCS = [
    "README.md",
    "REPO-COVERAGE.md",
    "RELEASE-NOTES-1.11.md",
    ".devcontainer/README.md",
    "exercises/README.md",
    "models/staging/_staging__models.yml",
    "models/marts/_marts__models.yml",
]

SUMMARY_RE = re.compile(
    r"Done\. PASS=(\d+) WARN=(\d+) ERROR=(\d+) SKIP=(\d+) NO-OP=(\d+) TOTAL=(\d+)"
)
# The deliberately elided form some prose uses: `PASS=117 ... TOTAL=120`
ELIDED_RE = re.compile(r"PASS=(\d+) (?:…|\.\.\.) TOTAL=(\d+)")

failures = []
notes = []


def run_dbt(args, expect_rc=None):
    p = subprocess.run([DBT, *args], cwd=ROOT, capture_output=True, text=True)
    if expect_rc is not None and p.returncode != expect_rc:
        failures.append("dbt %s exited %d, expected %d" % (" ".join(args), p.returncode, expect_rc))
    return p.stdout + p.stderr


def summary_of(out):
    hits = SUMMARY_RE.findall(out)
    return hits[-1] if hits else None


def read_docs():
    return {f: (ROOT / f).read_text(encoding="utf-8") for f in DOCS if (ROOT / f).exists()}


def rule(name, bound, problems):
    """Record one rule's outcome. Zero bindings is a failure -- see the module docstring."""
    if bound == 0:
        failures.append("%s: bound 0 occurrences -- this rule is watching nothing" % name)
        print("  DEAD  %s: matched no prose at all" % name)
        return
    if problems:
        failures.extend("%s: %s" % (name, p) for p in problems)
        print("  FAIL  %s: %d occurrence(s), %d disagree" % (name, bound, len(problems)))
        for p in problems:
            print("          " + p)
    else:
        print("  ok    %s: %d occurrence(s) agree" % (name, bound))


# The commands whose summary lines this repo quotes in prose, in an order where each one finds
# the state it needs. `retry` and the two `result:` selections all react to the run before them,
# so the forced failure is repeated rather than shared -- running a selection first overwrites
# the very run_results.json the next step reads, which is the trap the README now spells out.
#
# THE RULE RUNS MEASURED -> DOCS, NOT DOCS -> MEASURED. Asking "is every `Done.` line in the docs
# one of these?" flags the many legitimate receipts from commands this checker does not run.
# Asking "does each measured receipt still appear in the prose?" is the question staleness
# actually answers to: when a build's totals move, the string stops being found, and the check
# names which command moved and where it was quoted.
MEASURED_COMMANDS = [
    ("clean build",     ["build"], 0),
    ("empty ci build",  ["build", "--target", "ci", "--empty", "--full-refresh"], 0),
    ("unit tests",      ["test", "--select", "test_type:unit"], 0),
    ("sample build",    ["build", "--sample", "3 days", "--exclude",
                         "relationships_stg_order_items_order_id__order_id__ref_stg_orders_"], 0),
    ("forced failure",  ["build", "--vars", "{force_test_fail: true}"], 1),
    ("retry",           ["retry"], 1),
    ("forced failure",  ["build", "--vars", "{force_test_fail: true}"], 1),
    ("result:fail+",    ["build", "--select", "result:fail+", "--state", "./target",
                         "--vars", "{force_test_fail: true}"], 1),
    ("forced failure",  ["build", "--vars", "{force_test_fail: true}"], 1),
    ("1+result:fail+",  ["build", "--select", "1+result:fail+", "--state", "./target",
                         "--vars", "{force_test_fail: true}"], 1),
]


def check_run_summaries(docs):
    measured = {}
    for label, args, rc in MEASURED_COMMANDS:
        s = summary_of(run_dbt(args, expect_rc=rc))
        if s is None:
            failures.append("%s: dbt printed no 'Done.' summary line" % label)
            continue
        measured.setdefault(s, label)
        print("  measured %-16s PASS=%s WARN=%s ERROR=%s SKIP=%s NO-OP=%s TOTAL=%s"
              % (label, s[0], s[1], s[2], s[3], s[4], s[5]))

    # leave the warehouse in the state the rest of the repo expects
    run_dbt(["build"], expect_rc=0)

    bound, problems = 0, []
    for groups, label in measured.items():
        literal = ("Done. PASS=%s WARN=%s ERROR=%s SKIP=%s NO-OP=%s TOTAL=%s" % groups)
        hits = 0
        for f, text in docs.items():
            hits += text.count(literal)
            for m in ELIDED_RE.finditer(text):
                if (m.group(1), m.group(2)) == (groups[0], groups[5]):
                    hits += 1
        bound += hits
        if hits == 0:
            problems.append("%s now returns '%s', which appears in no documentation file"
                            % (label, literal))
    rule("run summaries", bound, problems)

    # The badge and the one-line headline both restate the clean build, and both have gone stale
    # before. Bind them by name so a silent divergence between them is impossible.
    clean = next((g for g, l in measured.items() if l == "clean build"), None)
    if clean:
        bound2, problems2 = 0, []
        readme = docs.get("README.md", "")
        for m in re.finditer(r"build-(\d+)%2F(\d+)%20passing", readme):
            bound2 += 1
            if (m.group(1), m.group(2)) != (clean[0], clean[5]):
                problems2.append("README badge says %s/%s; a clean build is %s/%s"
                                 % (m.group(1), m.group(2), clean[0], clean[5]))
        for m in re.finditer(r"build (\d+) of (\d+) passing", readme):
            bound2 += 1
            if (m.group(1), m.group(2)) != (clean[0], clean[5]):
                problems2.append("README badge alt-text says %s of %s; a clean build is %s of %s"
                                 % (m.group(1), m.group(2), clean[0], clean[5]))
        rule("build badge", bound2, problems2)
        check_clean_build_anchors(docs, clean)


# Every place the CLEAN BUILD receipt is restated, anchored by the words around it. The
# measured -> docs rule above proves the right string still exists SOMEWHERE; these anchors prove
# it exists in each of the places a reader actually looks. Without them, one file can go stale
# while its six siblings keep the rule green -- which is exactly how this repo shipped
# `PASS=116 ... TOTAL=119` in five documents at once.
CLEAN_BUILD_ANCHORS = [
    ("README.md", "your terminal reads"),
    ("README.md", "A green `dbt build` reports"),
    ("README.md", "Expected — this exact line, on both the first"),
    ("README.md", "builds **green over zero rows**"),
    ("README.md", "`dbt build --full-refresh` green"),
    ("REPO-COVERAGE.md", "What a clean run looks like"),
    ("REPO-COVERAGE.md", "| `dbt build` | `dbt build` →"),
    ("RELEASE-NOTES-1.11.md", "The measured final state"),
]


def check_clean_build_anchors(docs, clean):
    """Each anchored restatement of the clean-build receipt must be the measured one."""
    literal = "Done. PASS=%s WARN=%s ERROR=%s SKIP=%s NO-OP=%s TOTAL=%s" % clean
    bound, problems = 0, []
    for fname, anchor in CLEAN_BUILD_ANCHORS:
        text = docs.get(fname)
        if text is None or anchor not in text:
            problems.append("%s: anchor '%s' is gone -- this receipt is no longer watched"
                            % (fname, anchor))
            continue
        window = text[text.index(anchor): text.index(anchor) + 500]
        m = SUMMARY_RE.search(window) or ELIDED_RE.search(window)
        if m is None:
            problems.append("%s: no receipt found after '%s'" % (fname, anchor))
            continue
        bound += 1
        got = m.group(0)
        if got.startswith("Done."):
            if got != literal:
                problems.append("%s: after '%s' the receipt reads '%s'; a clean build is '%s'"
                                % (fname, anchor, got, literal))
        elif (m.group(1), m.group(2)) != (clean[0], clean[5]):
            problems.append("%s: after '%s' the receipt reads '%s'; a clean build is PASS=%s / TOTAL=%s"
                            % (fname, anchor, got, clean[0], clean[5]))
    rule("clean-build anchors", bound, problems)


def check_selectable_nodes(docs):
    out = run_dbt(["ls", "--output", "json", "--output-keys", "name"], expect_rc=0)
    count = sum(1 for line in out.splitlines() if line.startswith("{"))
    print("  measured %-16s %d selectable nodes" % ("dbt ls", count))
    pats = [
        re.compile(r"all (\d+) selectable nodes"),
        re.compile(r"returns all (\d+)\."),
        re.compile(r"package:dbtae_companion` → (\d+)\."),
        re.compile(r"out of (\d+) selectable"),
        re.compile(r"`dbt ls` offers (\d+)"),
    ]
    bound, problems = 0, []
    for f, text in docs.items():
        for pat in pats:
            for m in pat.finditer(text):
                bound += 1
                if int(m.group(1)) != count:
                    problems.append("%s: '%s' but dbt ls returns %d" % (f, m.group(0), count))
    rule("selectable node count", bound, problems)


def check_exercise_inventory(docs):
    n = sum(1 for p in (ROOT / "exercises").iterdir() if p.is_dir())
    print("  measured %-16s %d case directories" % ("exercises/", n))
    words = {20: "twenty", 21: "twenty-one", 22: "twenty-two", 23: "twenty-three", 24: "twenty-four"}
    want_word = words.get(n)
    num_pats = [
        re.compile(r"asserts all (\d+)"),
        re.compile(r"all (\d+) and asserts"),
        re.compile(r"all (\d+) triage cases"),
        re.compile(r"\*\*(\d+)\*\* \| broken-example"),
        re.compile(r"(\d+) broken cases"),
        re.compile(r"(\d+) deliberately-broken cases"),
    ]
    word_pats = [
        re.compile(r"holds \*\*([a-z-]+)\*\* deliberately-broken cases"),
        re.compile(r"all ([a-z-]+) triage (?:cases|fixtures)"),
        re.compile(r"([a-z-]+) broken files"),
        re.compile(r"as ([a-z-]+) fixture failures"),
    ]
    bound, problems = 0, []
    for f, text in docs.items():
        for pat in num_pats:
            for m in pat.finditer(text):
                bound += 1
                if int(m.group(1)) != n:
                    problems.append("%s: '%s' but exercises/ holds %d" % (f, m.group(0), n))
        for pat in word_pats:
            for m in pat.finditer(text):
                bound += 1
                if want_word and m.group(1) != want_word:
                    problems.append("%s: '%s' but exercises/ holds %d (%s)"
                                    % (f, m.group(0), n, want_word))
    rule("exercise inventory", bound, problems)


def main():
    offline = "--offline" in sys.argv
    docs = read_docs()
    if not docs:
        print("no documentation files found", file=sys.stderr)
        return 2

    print("== receipts ==")
    if offline:
        notes.append("--offline: run summaries and the node count were not re-measured")
    else:
        check_run_summaries(docs)
        check_selectable_nodes(docs)
    check_exercise_inventory(docs)

    print()
    for n in notes:
        print("  note: " + n)
    if failures:
        print("\n%d receipt(s) disagree with the project:" % len(failures))
        for f in failures:
            print("  - " + f)
        return 1
    print("\nAll receipts agree with what the project actually produces.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
