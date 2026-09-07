# dbt AE Certification — Hands-On Companion

> ### 📘 Studied from the dbt 1.7 material? Download the free 1.7 → 1.11 delta booklet
>
> **[dbt-analytics-engineer-1.7-to-1.11-delta.pdf](../../releases/latest)** — 93 pages
> covering everything the study guide changed between dbt Core 1.7 and 1.11: the five new Topic 1
> bullets, microbatch and `--sample`, YAML constraints, the behaviour-change flags and
> deprecations, freshness and state, and 64 practice questions with worked answers.
>
> Grab it from the [latest release](../../releases/latest). Nothing in it is repeated from the
> 1.7 material — it is the delta only.


> A runnable dbt 1.11 project on Postgres that exercises the exam patterns that translate to a local warehouse — sources, materializations (including microbatch), snapshots (SQL-block and YAML), tests (including unit tests), macros, packages, documentation, governance, contracts, grants, state/defer, and slim CI. Click *Reopen in Container*, run three commands, and your terminal reads `Done. PASS=117 WARN=0 ERROR=0 SKIP=0 NO-OP=3 TOTAL=120`. The handful of things the exam names that genuinely cannot run on Postgres — Python models and true zero-copy clones among them — are called out rather than faked; see [*What this repo can't demonstrate*](#what-this-repo-cant-demonstrate).

<p>
  <a href="https://docs.getdbt.com/docs/dbt-versions/core-upgrade/upgrading-to-v1.11"><img src="https://img.shields.io/badge/dbt--core-1.11.14-FF694A?logo=dbt&logoColor=white" alt="dbt 1.11.14"></a>
  <img src="https://img.shields.io/badge/dbt--postgres-1.11.0-336791?logo=postgresql&logoColor=white" alt="dbt-postgres 1.11.0">
  <img src="https://img.shields.io/badge/postgres-15-336791?logo=postgresql&logoColor=white" alt="Postgres 15">
  <img src="https://img.shields.io/badge/python-3.11-3776AB?logo=python&logoColor=white" alt="Python 3.11">
  <img src="https://img.shields.io/badge/devcontainer-ready-2496ED?logo=docker&logoColor=white" alt="devcontainer">
  <img src="https://img.shields.io/badge/build-117%2F120%20passing-brightgreen" alt="build 117 of 120 passing">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="MIT license">
</p>

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new/?quickstart=1&repo=snowleafbooks%2Fdbt-analytics-engineer-certification)

---

## 📖 Companion to the book

This repo is the hands-on lab for **_dbt Analytics Engineer Exam Prep_** — the textbook side of the same material.

<table>
  <tr>
    <td width="240" valign="top">
      <a href="https://mybook.to/dbt-ae-exam-prep">
        <img src="assets/front-cover.png" alt="dbt Analytics Engineer Exam Prep — book cover" width="220">
      </a>
    </td>
    <td valign="top">
      <p>Read the concepts, then run them here. The book covers every topic on the current official study guide with worked examples; this repo lets you execute, break, and inspect them on a local Postgres warehouse.</p>
      <p>
        <a href="https://mybook.to/dbt-ae-exam-prep">
          <img src="https://img.shields.io/badge/Buy_on_Amazon-FF9900?style=for-the-badge&logo=amazon&logoColor=white" alt="Buy on Amazon">
        </a>
      </p>
      <sub>The link auto-redirects to your local Amazon marketplace (US, UK, DE, FR, IT, ES, CA, AU, JP, IN, …).</sub>
    </td>
  </tr>
</table>

### Which version of this repo do you want?

`main` tracks the current revision. Every revision is also tagged, so you can check out the tree that
matches the study guide you are working from:

| Revision | Study guide | Repo tag | Pins |
|---|---|---|---|
| **1.11 (current)** | v1.11 — dbt Core 1.11 | [`study-guide-dbt-1.11`](https://github.com/snowleafbooks/dbt-analytics-engineer-certification/tree/study-guide-dbt-1.11) | dbt-core 1.11.14 / dbt-postgres 1.11.0 · 119 nodes |
| 1.7 | V.9.0 — dbt Core 1.7 | [`study-guide-dbt-1.7`](https://github.com/snowleafbooks/dbt-analytics-engineer-certification/tree/study-guide-dbt-1.7) | dbt-core 1.8.9 / dbt-postgres 1.8.2 · 109 nodes |

```bash
git clone https://github.com/snowleafbooks/dbt-analytics-engineer-certification.git
cd dbt-analytics-engineer-certification
git checkout study-guide-dbt-1.11        # or study-guide-dbt-1.7 for the earlier revision
```

The 1.7 tag pins dbt **1.8**, not 1.7: 1.8 was the runnable release at the time, and that
revision flagged 1.8-only features as sidebars against a 1.7 exam. The tag names the study guide it
ships against, not the pinned runtime.

---

## Who is this for?

- **Candidates preparing for the dbt Analytics Engineer Certification** who want to *run* the concepts, not just read about them
- **Engineers new to dbt** who want a complete, opinionated reference project — seeds, sources, staging/marts, snapshots, tests, docs, grants — all wired up and green
- **Instructors / team leads** building a training environment: every exam concept has a concrete, minimal example you can point at

This repo is a **lab**, not a tutorial. It's designed to be explored by running commands and reading diffs. Pair it with the [official dbt docs](https://docs.getdbt.com/docs) for the textbook side.

## What's in the box

| | |
|---:|---|
| **19** | models (6 views + 1 ephemeral + 6 tables + 5 incrementals + 1 materialized view) |
| **4** | incremental strategies (`append`, `delete+insert`, native `merge`, `microbatch`) |
| **4** | `on_schema_change` values, all four demonstrated — `append_new_columns`, `ignore`, `sync_all_columns`, `fail` |
| **3** | snapshots — two SQL-block, one YAML-defined; timestamp strategy, `check_cols: all`, and an explicit `check_cols` list |
| **89** | data tests — 86 generic (incl. one custom generic and two from packages) + 3 singular |
| **3** | unit tests — one per available mock shape (`fixture:` files under `tests/fixtures/`, and inline `rows:`), plus one that proves `overrides.macros` reaches a macro the model never names |
| **4** | Hub packages (dbt_utils, dbt_expectations, audit_helper, codegen) — `dbt_date` arrives transitively |
| **5** | constraint types (`not_null`, `unique`, `check`, `primary_key`, `foreign_key`) across 4 contracted models — 5 contracted *nodes*, because `dim_customer_segments` ships as v1 and v2 |
| **3** | exposures (dashboard + ml + analysis) |
| **22** | broken-example drills for triage practice, with a harness that asserts all 22 |

A green `dbt build` reports `Done. PASS=117 WARN=0 ERROR=0 SKIP=0 NO-OP=3 TOTAL=120`. Don't
try to reconcile that `TOTAL` with the table above by adding rows up: it *adds* the two project
hooks and the three exposures (which are the `NO-OP=3`) and *omits* the ephemeral model, which
is inlined rather than materialized. Compare your terminal against the summary line, not
against an arithmetic count of files.

Full concept-to-file mapping: **[REPO-COVERAGE.md](REPO-COVERAGE.md)**. What the 1.11 upgrade
changed: **[RELEASE-NOTES-1.11.md](RELEASE-NOTES-1.11.md)**. The container and its verification
scripts: **[`.devcontainer/README.md`](.devcontainer/README.md)**.

---

## Table of contents

- [Quickstart](#quickstart-2-minutes)
- [Your first 10 minutes](#your-first-10-minutes)
- [What's inside](#whats-inside)
- [Project layout](#project-layout)
- [Useful commands](#useful-commands-to-try)
- [Stack](#stack)
- [What this repo can't demonstrate](#what-this-repo-cant-demonstrate)
- [Troubleshooting](#troubleshooting)
- [Prerequisites](#prerequisites)
- [Contributing](#contributing)

---

## Prerequisites

Install these before you clone the repo — in this order:

1. **Docker Desktop** — [Windows](https://docs.docker.com/desktop/install/windows-install/) / [Mac](https://docs.docker.com/desktop/install/mac-install/) / on Linux use [Docker Engine](https://docs.docker.com/engine/install/) directly. During the Windows install, **enable the WSL 2 integration** option; on Mac just accept the defaults. After install, launch Docker Desktop at least once and confirm it's running (whale icon in the tray / menubar).
2. **VS Code** — [download](https://code.visualstudio.com/).
3. **Dev Containers extension** — install the `ms-vscode-remote.remote-containers` extension from the VS Code Marketplace.
4. **Git** — any recent version. On Windows, `winget install Git.Git` or use [Git for Windows](https://git-scm.com/download/win).

> **Windows-specific note.** Docker Desktop is required — installing Docker CE *inside* a WSL distro alone does **not** work with VS Code's *Reopen in Container* from a Windows-side path. Docker Desktop ships the WSL integration the Dev Containers extension expects.

Verify before proceeding:

```bash
docker --version     # Docker version 24.x or later
docker ps            # should succeed (may list no containers)
code --version       # VS Code 1.85 or later
```

If `docker ps` errors with "Cannot connect to the Docker daemon", Docker Desktop isn't running — start it and retry.

**Disk budget:** ~3 GB total (Docker Desktop ~2 GB + `postgres:15` + `python:3.11-bookworm` + dbt deps ~1 GB).

---

## Quickstart (2 minutes)

### Option A — VS Code Dev Container (recommended)

```bash
git clone https://github.com/snowleafbooks/dbt-analytics-engineer-certification.git
cd dbt-analytics-engineer-certification
code .
```

In VS Code: `Ctrl/Cmd+Shift+P` → **Dev Containers: Reopen in Container**. First open takes ~2 min (image build + Postgres init). You'll land in a terminal inside the container with dbt + Postgres ready.

```bash
dbt deps    # install Hub packages
dbt seed    # load reference CSVs
dbt build   # compile + run + test + snapshot, DAG-ordered
```

Expected — this exact line, on both the first (`--full-refresh`) and the incremental path:

```
Done. PASS=117 WARN=0 ERROR=0 SKIP=0 NO-OP=3 TOTAL=120
```

One `[WARNING]` also appears above it on every parse, naming `dim_customer_segments.v1`. That
is deliberate — see [Troubleshooting](#troubleshooting). `WARN=0` in the summary counts *test*
warnings only, so the two are not in conflict.

### Option B — GitHub Codespaces (zero local install)

Click the Codespaces badge above. Same three commands once your terminal loads.

### Option C — Local Postgres + venv (no Docker)

<details>
<summary>Expand — requires your own Postgres 15</summary>

Two things the container hands you that this path does not, and both fail silently:

- **The names are not yours to choose.** `db-init/01-roles.sql` grants `CONNECT ON DATABASE dbtae`
  and `db-init/02-schemas.sql` creates the raw schemas `AUTHORIZATION dbt_developer`. Against any
  other database or role, every statement after the first fails — and psql still exits **0**.
- **`db-init/04-load-raw.sql` is written for the container**, where `docker-compose.yml` mounts
  `data-seed/` at `/data-seed`. `\COPY` is a *client-side* command, so on your own machine that
  absolute path does not exist, all six loads fail, and psql exits 0 again. Left uncaught, the lab
  then builds **green over zero rows** — `Done. PASS=117 … TOTAL=120` with nothing in it, because
  `not_null` and `unique` pass vacuously on an empty relation.

`-v ON_ERROR_STOP=1` is what turns both of those into a non-zero exit instead of a warehouse that
lies to you.

```bash
python -m venv .venv
source .venv/bin/activate         # macOS / Linux
# .venv\Scripts\Activate.ps1       # Windows PowerShell
pip install -r requirements.txt

# 01-roles.sql creates the four grantee roles, so dbt_developer needs CREATEROLE. Make it the
# database owner, as the container does, so dbt can create the dev/ci schemas.
psql -U postgres -c "create role dbt_developer login createrole password 'dbt_developer_pw';"
createdb -U postgres -O dbt_developer dbtae

# Apply the init scripts from the repo root.
psql -v ON_ERROR_STOP=1 -U dbt_developer -d dbtae -f db-init/01-roles.sql
psql -v ON_ERROR_STOP=1 -U dbt_developer -d dbtae -f db-init/02-schemas.sql
psql -v ON_ERROR_STOP=1 -U dbt_developer -d dbtae -f db-init/03-raw-tables.sql

# Rewrite the container path to the repo-relative one, and load.
sed 's#/data-seed/#data-seed/#g' db-init/04-load-raw.sql \
  | psql -v ON_ERROR_STOP=1 -U dbt_developer -d dbtae
# Windows PowerShell, same step in two lines:
#   (Get-Content db-init/04-load-raw.sql) -replace '/data-seed/','data-seed/' |
#     Set-Content $env:TEMP\04-load-raw.local.sql
#   psql -v ON_ERROR_STOP=1 -U dbt_developer -d dbtae -f $env:TEMP\04-load-raw.local.sql

mkdir -p ~/.dbt && cp profiles.yml.example ~/.dbt/profiles.yml
export POSTGRES_HOST=127.0.0.1    # the profile defaults to `postgres`, the compose service name

dbt debug && dbt deps && dbt seed && dbt build
```

The six `COPY <n>` lines are the receipt; the counts they should print are in
[`data-seed/GENERATED.md`](data-seed/GENERATED.md). If you get no `COPY` lines, fix the load
before you run dbt — the build will not tell you.

One more thing to carry into the next section: every `psql` line in
[Your first 10 minutes](#your-first-10-minutes) uses `-h postgres`, the compose service name. On
this path drop the flag or use `-h localhost`, and substitute your own credentials.

</details>

---

## Your first 10 minutes

After `dbt build` is green, work through these in order. Each one takes under a minute and surfaces a concept the certification tests.

The `psql` lines below are written for the dev container: `-h postgres` is the compose service
name and resolves only on that network (elsewhere psql answers `could not translate host name
"postgres" to address`). On a local Postgres — [Option C](#option-c--local-postgres--venv-no-docker) — drop the flag and use your own credentials.

### 1 — Open the docs site

```bash
dbt docs generate && dbt docs serve --port 8080
```

Open <http://localhost:8080>. Click through the DAG — every node has descriptions, column types, and lineage pre-wired.

### 2 — See `persist_docs` in action

```bash
psql -h postgres -U dbt_developer -d dbtae -c "\d+ dev.fct_orders"
```

The column descriptions from [`_marts__models.yml`](models/marts/_marts__models.yml) are now `COMMENT ON COLUMN` values in Postgres. Any SQL client will see them.

### 3 — Prove `grants:` merge vs replace

```bash
psql -h postgres -U dbt_developer -d dbtae <<'SQL'
SELECT table_name, grantee, privilege_type
  FROM information_schema.role_table_grants
 WHERE grantee IN ('bi_reader','analytics_reader','finance_reader')
   AND table_schema = 'dev'
 ORDER BY table_name, grantee;
SQL
```

You'll see:
- `fct_orders` grants SELECT only to `bi_reader` — the model-level `grants:` **replaced** the parent `analytics_reader`
- `fct_order_items` grants SELECT to **both** `analytics_reader` and `finance_reader` — the `'+select':` prefix **merged**
- Everything else inherits `analytics_reader` from the folder-level default

This is the clearest hands-on demo of dbt grants semantics you'll find.

### 4 — Capture SCD2 history with a snapshot

```bash
dbt snapshot                                                              # first snapshot
psql -h postgres -U dbt_developer -d dbtae -f scripts/mutate-customers.sql
dbt snapshot                                                              # second snapshot picks up the mutation
psql -h postgres -U dbt_developer -d dbtae -c \
  "SELECT customer_id, email, dbt_valid_from, dbt_valid_to
     FROM dev_snapshots.snp_customers_timestamp
    WHERE customer_id = 7
    ORDER BY dbt_valid_from"
```

Two rows appear for customer 7 — the original and the post-mutation version, with `dbt_valid_from` / `dbt_valid_to` marking the transition.

This drill is **one-way**: every run of it mints one more SCD2 version, so `snp_customers_timestamp` grows by a row each time. A fresh clone starts at 200.

### 5 — Run a slim-CI build

The baseline this needs is not "whatever is in `target/` right now" — a baseline identical to
your working tree makes `state:modified` select nothing. `--rebase` builds it from the
committed pre-change state in [`scripts/baseline-preimage/`](scripts/baseline-preimage/), so
there is a real, designed delta to select: `stg_products` refactored onto the shared
`cents_to_dollars()` macro, and one singular test that does not exist in the baseline at all.

```bash
# 0. the ci schema must be empty — without --favor-state dbt prefers a relation that
#    already exists in the current target over the deferred one
psql -h postgres -U dbt_developer -d dbtae -c 'drop schema if exists ci cascade;'
psql -h postgres -U dbt_developer -d dbtae -c 'drop schema if exists ci_snapshots cascade;'
psql -h postgres -U dbt_developer -d dbtae -c 'drop schema if exists ci_reference cascade;'
psql -h postgres -U dbt_developer -d dbtae -c 'drop schema if exists ci_dbt_test__audit cascade;'

# 1. build the teaching baseline from the documented pre-change state
bash scripts/save-baseline.sh --rebase

# 2. see what changed
dbt ls --select state:modified --state ./prior-artifacts --resource-type model
dbt ls --select state:new      --state ./prior-artifacts

# 3. run the slim CI
bash scripts/slim-ci.sh
```

Expected:

```
Done. PASS=17 WARN=0 ERROR=0 SKIP=0 NO-OP=1 TOTAL=18
```

Then look at what actually landed in the warehouse: `ci` holds **three** relations
(`stg_products`, `dim_products`, `fct_order_items`), not eighteen. Everything upstream and
unmodified was resolved by `--defer --state` to the baseline's relations in `dev` instead of
being rebuilt. That is the whole point of the pattern, and the schema is the proof.

`bash scripts/save-baseline.sh` with no argument still snapshots the **current** state — use
that when you want to make your own edit and diff against it.

More selectors to run against this baseline are in [State selection](#state-selection).

### 6 — Run the unit tests

```bash
dbt test --select test_type:unit
```

Expected: `Done. PASS=5 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=5` — the three unit tests plus the two project hooks.

Two of them are declared in [`_marts__models.yml`](models/marts/_marts__models.yml) and validate `fct_orders`'s USD-conversion logic against mocked input rows rather than against production source rows. That is not the same as running without a warehouse: the `unit` materialization creates a temporary relation, reads its columns back, and executes the test SQL through the adapter, so a connection is still required. Point `POSTGRES_PORT` at a closed port and `dbt test --select test_type:unit` dies with `Database Error / connection to server ... failed`. What mocks remove is the dependency on the *data*, not the round-trip. They are written in the two available shapes on purpose: `test_fct_orders_usd_conversion` uses the **fixture-file** form, with its mock rows as CSVs in [`tests/fixtures/`](tests/fixtures/) referenced by `fixture:`; `test_fct_orders_no_rate_match_defaults_to_one` holds its rows **inline** under `rows:`, including an empty rate input — a header row with no data rows, which is how you mock "this relation is empty".

The third, `test_stg_customers_override_reaches_nested_macro`, sits in [`_staging__models.yml`](models/staging/_staging__models.yml) and makes a different point: an `overrides.macros` entry substitutes the macro **wherever it is resolved while the test runs**, including inside macros the model only reaches indirectly. Its `description:` carries the call chain, the hash arithmetic, and the one place the substitution stops.

### 7 — Force a failure, then retry

```bash
dbt build --vars '{force_test_fail: true}'      # one test fails, 10 downstream nodes skipped
```

Expected: `Done. PASS=109 WARN=0 ERROR=1 SKIP=10 NO-OP=1 TOTAL=121`, exit 1.

Now pick **one** of the two recoveries below. They are alternatives, not steps, and running the
selection first destroys the state the second one needs — `--state ./target` is the same
directory `dbt` is about to overwrite.

```bash
dbt retry                                       # A: resume the invocation that just failed
```

`Done. PASS=2 WARN=0 ERROR=1 SKIP=10 NO-OP=0 TOTAL=13`, exit 1. Retry reads
`target/run_results.json` and re-runs the nodes that did not finish — the failed test and the ten
it skipped — **not** all 121 nodes of the original invocation. "Replays the previous command" is
the wrong mental model; "resumes the unfinished part of it" is the right one. It does replay the
previous `--vars`, `--target` and `--threads`, which is why the `--vars` is not repeated here.

```bash
dbt build --select 1+result:fail+ --state ./target --vars '{force_test_fail: true}'   # B
```

`Done. PASS=18 WARN=0 ERROR=1 SKIP=0 NO-OP=0 TOTAL=19`, exit 1. Four details worth more than they
look:

- It is **`result:fail`**, not `result:error`. A data test that returns failing rows has status `fail`; `error` is for a node that blew up. `result:error+` selects nothing here.
- The **`1+` prefix is doing the real work.** A bare `result:fail+` selects the failed node and its *descendants* — and a data test has none, so it returns `TOTAL=3`: the test and the two project hooks, with none of the ten skipped models. Those models are downstream of the test's *parent*, so you have to step up one level first. Measured: `result:fail+` → `Done. PASS=2 WARN=0 ERROR=1 SKIP=0 NO-OP=0 TOTAL=3`, against `1+result:fail+` → `TOTAL=19`.
- `result:` needs **`--state`** pointing at the artifacts of the run you are reacting to — `./target` is where that run just wrote them. Without it dbt exits 2 with `Internal Error / No comparison run_results`.
- The `--vars` has to be repeated, because the fixture test is `enabled:`-gated on that var. Drop it and the node is not in the current manifest at all, so nothing can select it.

### 8 — Grade a test with `warn_if` / `error_if`

One singular test, one var, three different outcomes:

```bash
dbt test --select assert_large_orders_within_review_tolerance                                  # PASS
dbt test --select assert_large_orders_within_review_tolerance --vars '{large_order_review_usd: 500}'  # WARN
dbt test --select assert_large_orders_within_review_tolerance --vars '{large_order_review_usd: 150}'  # FAIL
```

[`tests/assert_large_orders_within_review_tolerance.sql`](tests/assert_large_orders_within_review_tolerance.sql) is configured `severity='error'`, `warn_if='>= 8'`, `error_if='>= 30'`, over orders above `var('large_order_review_usd', 1000)`. Lowering the dollar threshold raises the returned row count past each boundary in turn. The lesson a lot of readers miss: a singular test is **not** simply "returns rows = failed" — `warn_if`/`error_if` turn the count into a graded signal. And `error_if` is only consulted when severity is `error`, so `severity='warn'` would make it unreachable. The row counts move with the fixture's rolling window; the three outcomes do not.

### 9 — Build the shape without the data

```bash
dbt build --target ci --empty --full-refresh
```

Expected: `Done. PASS=117 WARN=0 ERROR=0 SKIP=0 NO-OP=3 TOTAL=120` — the same green line as a real build, over zero rows. Every DDL, contract and constraint is exercised; every `not_null` and `unique` test passes vacuously. That is `--empty`'s value (schema-only CI in seconds) and its trap (a green suite that asserted nothing) in one command.

Then sample a time window instead of emptying it:

```bash
dbt run --sample '3 days'
```

`--sample` filters on the `event_time` declared on the source, so it only narrows models downstream of a source that has one. Note that `dbt build --sample` is *not* green here: sampling `stg_orders` orphans every line item, so the `stg_order_items → stg_orders` `relationships` test fails on the truncated window. That is inherent, not a bug — only `stg_orders` can declare `event_time`. To see the sampled build succeed, exclude that one test:

```bash
dbt build --sample '3 days' \
  --exclude relationships_stg_order_items_order_id__order_id__ref_stg_orders_
```

Pick your window from the fixture's own horizon, documented in [`data-seed/GENERATED.md`](data-seed/GENERATED.md) — a window outside it returns zero rows and still goes green, which is the same trap from the other direction.

### 10 — Break something on purpose

The [`exercises/`](exercises/) directory has **22 broken cases** — cyclic refs, contract drift, a contracted column missing its `data_type`, access violations, a mis-pointed source, YAML errors, dispatch misses, Jinja syntax, macro arity and an unquoted macro argument, versioned and disabled `ref()`s, plus a hard-coded relation, a conditional `ref()` and the `-- depends_on:` escape hatch. Each sub-directory has a README with the trigger command, the exit code, the layer it fails at (parse / compile / run) and the error string dbt actually emits, captured from a real run.

The trigger flow is identical for every case — copy the case's files into `models/_tmp_broken/`, run one command, read the result, delete the directory. There is no `.broken` suffix and no `.dbtignore` edit: `exercises/` sits outside every `*-paths` entry, so dbt never walks it. Five of the cases exit **0**: nothing is reported, and the diagnosis is in `target/manifest.json` rather than the log — those are the ones worth your time. [`exercises/README.md`](exercises/README.md) has the flow and the full catalogue.

```bash
bash .devcontainer/_test_exercises.sh    # runs all 22 and asserts each one's exit code, layer, message or recorded DAG edges
```

Expected: `=== Summary: 22 PASS / 0 FAIL ===`. The suite runs exactly the steps the READMEs document, so the drills and the docs cannot drift apart. Five more verification scripts live alongside it — see [`.devcontainer/README.md`](.devcontainer/README.md).

---

## What's inside

| Area | Highlights |
|---|---|
| **Models** | staging → intermediate (ephemeral) → marts (tables + incrementals + one materialized view). Four incremental strategies: `append`, `delete+insert`, native Postgres 15 `MERGE`, and `microbatch` — which on dbt-postgres is *also* implemented as `MERGE`, so `unique_key` is mandatory |
| **Governance** | Enforced contracts on four models — five nodes, since `dim_customer_segments` is versioned — with 5 Postgres constraint types across them: `not_null`, `check` (on `dim_products.price_cents`), `unique`, `primary_key`, and a `foreign_key` on `fct_segment_activity.customer_id` → `dim_customer_segments` v1 in the `to:` / `to_columns:` form. Two versions of `dim_customer_segments` with `latest_version: 2` and a `deprecation_date` on v1, which makes every downstream `ref()` to v1 emit an upcoming-deprecation advisory. Three declared groups, `access: private/protected/public` |
| **Tests** | 89 data tests (86 generic, 3 singular) + 3 unit tests. Covers `unique`, `not_null`, `accepted_values`, `relationships`, singular tests, custom generic tests with args, package tests, plus common test configs (`severity`, `warn_if` / `error_if`, `store_failures`, `where`, `limit`). Two of the unit tests show both mock shapes — `fixture:` files over CSVs in `tests/fixtures/`, and inline `rows:` — and the third shows that `overrides.macros` reaches a macro the model never names |
| **Packages** | `dbt_utils`, `dbt_expectations`, `audit_helper`, `codegen` (plus `dbt_date`, pulled in transitively by `dbt_expectations`). Dispatch override of `dbt_utils.generate_surrogate_key` via `macros/generate_surrogate_key.sql`, which defines `default__generate_surrogate_key` — the **macro name** is what makes the override win |
| **Docs** | Doc blocks, `{{ doc() }}`, `persist_docs: {relation: true, columns: true}` → Postgres `COMMENT ON`, three exposures (dashboard + ml + analysis), `meta:` inheritance |
| **State / CI** | `scripts/save-baseline.sh --rebase` (builds a baseline with a designed delta, from the committed preimage in `scripts/baseline-preimage/`) + `scripts/slim-ci.sh` + `scripts/clone-demo.sh`. Full `state:modified+ --defer --state ./prior-artifacts` recipe, plus `--favor-state` and the `state:modified.*` sub-methods |
| **Exercises** | 22 deliberately-broken cases, each with README + observed exit code, failure layer and error string — or, for the five that fail nothing, the manifest fact that is the only evidence — and a harness that asserts all 22 |

---

## Project layout

```
dbt-analytics-engineer-certification/
├── .devcontainer/    VS Code + Docker scaffolding, plus a verification suite (README.md)
├── db-init/          Postgres init (roles, schemas, raw tables)
├── data-seed/        Generated CSVs loaded into raw schema on first container boot
│   └── GENERATED.md  How they're generated, and the time window they cover
├── scripts/          Baseline / slim-CI / clone / freshness / mutation / reset helpers
│   └── baseline-preimage/   Committed pre-change state the teaching baseline is built from
├── seeds/            dbt seeds (reference data — distinct from sources)
├── models/
│   ├── sources.yml   Two sources across two schemas, six source tables
│   ├── _groups.yml   pii / marketing / finance groups
│   ├── exposures.yml Three exposures
│   ├── docs/         Doc blocks
│   ├── staging/      Views over sources, column renames
│   ├── intermediate/ One ephemeral model
│   └── marts/        Dims, facts, versioned model, materialized view, microbatch, contracts
├── snapshots/        Two SQL-block snapshots + _snapshots.yml (the YAML form)
├── tests/            Singular + custom generic + unit-test fixtures/
├── macros/           Dispatch override, audit columns, query_comment, custom schema
├── analyses/         audit_helper.compare_relations example
├── exercises/        22 broken cases for triage practice
├── dbt_project.yml
├── packages.yml
├── selectors.yml     Three named selectors (nightly_core, slim_ci, critical_only)
├── profiles.yml.example
├── requirements.txt  dbt-core==1.11.14  dbt-postgres==1.11.0
├── REPO-COVERAGE.md  Build spec: exam concept → repo artifact
└── RELEASE-NOTES-1.11.md   What the 1.11 upgrade changed
```

`prior-artifacts/` is **not** in the repo — it is gitignored build output. A fresh clone
regenerates it in about fifteen seconds with `bash scripts/save-baseline.sh --rebase`, which is
the prerequisite for every `state:` / `--defer` / `result:` / `source_status:` demo below. What
*is* committed is `scripts/baseline-preimage/`, the pre-change project state the baseline is
built from.

---

## Useful commands to try

### Discovery

```bash
dbt ls                                    # all 125 selectable nodes
dbt ls --resource-type model              # 19
dbt ls --select +fct_orders               # ancestors
dbt ls --select fct_orders+               # descendants
dbt ls --select @fct_orders               # ancestors + test deps
dbt ls --select '+exposure:executive_kpi_dashboard'
dbt ls --select 'tag:daily,tag:critical'  # intersection (comma, no space)
dbt ls --select 'staging.stg_*'           # fqn wildcard — see the note below
dbt ls --select 'tag:pii_*'               # wildcards work on tag: too
dbt ls --resource-type analysis           # analyses are outside dbt ls's default set
```

Two selector traps this project can show you rather than tell you:

- A bare `stg_*` selects **nothing**. The `fqn` method matches path-qualified names, so it needs a path segment (`staging.stg_*`, `models/staging/stg_*`) or a leading wildcard (`*stg_*`). All three select 34.
- `dbt ls --select package:dbt_utils` selects **nothing** either, and the method is fine — `dbt_utils` contributes macros, and macros are not selectable nodes. `dbt ls --select package:dbtae_companion` returns all 125.

Analyses are the third: they are excluded from `dbt ls`'s **default resource-type set**, and `--select` cannot add them back. `--resource-type analysis` lists it; `dbt compile --select resource_type:analysis` compiles it. `analysis:<name>` is not a valid selector method at all.

### Preview a relation without materializing it

```bash
dbt show --select dim_customers --limit 5
dbt show --select stg_orders --limit 5
dbt show --select fct_daily_sales --limit 5
dbt show --inline "select count(*) from {{ ref('fct_orders') }}"
```

`dbt show` runs the node's **compiled** SQL and prints a preview — it does not build anything.

That has one consequence worth meeting deliberately: `dbt show --select fct_orders --limit 3` prints the header row and **no data**. The cause is the model's own body, not its materialization: `dbt show` compiles `fct_orders` with `is_incremental()` **true** — the relation exists, so the `{% if is_incremental() %}` branch is rendered — and that branch is a strict watermark, `and orders.updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})`. Right after a build nothing clears that bar, so the preview is an empty delta. The model is full; the preview is not — the last line above proves it, by counting through a `ref()` instead of previewing the node.

Do not read that as "incremental models preview empty". `fct_daily_sales` also previews empty immediately after it consumes its parent build: its strict `dbt_updated_at > max(source_built_at)` predicate has no changed day to return. `fct_orders_microbatch` previews in full, because a microbatch model has **no `is_incremental()` guard at all** — dbt builds the batch filter from `event_time`, and none of it survives into the preview. `fct_order_items` and `fct_audit_events` do preview empty, and both for the same reason as `fct_orders`: a strict `>` watermark. The rule to carry away is that `dbt show` previews the compiled SQL, so whatever filter the author wrote inside `is_incremental()` is what you see. To look at the stored table instead, use `--inline` with a `ref()`, or point `show` at a view or table model.

(`--show` is a different thing, and it belongs to the other command: it is a flag on **`dbt seed`**,
meant to print a sample of the rows just loaded. `dbt show` rejects it, with
`Error: No such option: --show` and exit 2. Don't reach for it on `dbt seed` either at this
version: `dbt seed --show` dies with `AttributeError: 'NoneType' object has no attribute
'order_by'` and exits 2. That is an upstream bug, not a repo one — preview a seed with
`dbt show --select country_codes` instead.)

### Selectors

```bash
dbt ls --select 'group:pii'               # 4 — one model plus its three tests
dbt ls --select 'access:private'
dbt ls --select 'version:latest'          # also: old / prerelease / none
dbt build --selector nightly_core         # named selector from selectors.yml
dbt build --selector critical_only
```

`_groups.yml` declares three groups, but only two have members: `dbt ls --select group:finance` returns `No nodes selected!`. A group is a declaration, not a graph.

### Incremental strategies

```bash
dbt run --full-refresh --select fct_orders          # delete+insert
dbt run --select fct_audit_events                   # append
dbt run --select fct_order_items                    # merge (native Postgres 15 MERGE)
dbt run --full-refresh --select fct_orders_microbatch   # microbatch
```

Choosing between them is a named exam skill, so here is the mapping this repo demonstrates:

| Dataset shape | Strategy | Model here | Adapter requirement |
|---|---|---|---|
| Append-only event stream — rows are never updated or deleted, and an ascending id or timestamp gives a safe watermark | `append` | `fct_audit_events` | none. No `unique_key`; duplicates are your problem if the watermark is wrong |
| Late-arriving updates to a bounded recent window, where replacing the affected keys wholesale is easier to reason about than a row-by-row match | `delete+insert` | `fct_orders` | needs `unique_key`. Two statements, one transaction — see the note below |
| High-cardinality upserts where most of the batch is unchanged and you want dbt to match and update row by row | `merge` | `fct_order_items` (composite `unique_key`) | native `MERGE`: Postgres 15+, or Snowflake / BigQuery / Databricks. There is **no version fallback** — see below |
| Time-partitioned backfill of a large history, where the load must split so a failure is retryable per period rather than for the whole model | `microbatch` | `fct_orders_microbatch` | upstream must declare `event_time`; the model needs `event_time`, `begin`, `batch_size`. **On dbt-postgres this is implemented as MERGE, so `unique_key` is mandatory** — omit it and the failure is delayed to batch 2 |
| Partition-level overwrite | `insert_overwrite` | *not demonstrated* — dbt-postgres cannot | BigQuery / Spark / Databricks |

**"Two statements" is not "two transactions".** `delete+insert` compiles to a `delete ... where
unique_key in (select ... from temp)` followed by an `insert into ... select`, and it is tempting
to read that as a window in which the target sits emptied. It is not. Both statements are inside
the single `{% call statement("main") %}` of dbt's incremental materialization, and the
materialization reaches `{% do adapter.commit() %}` only after them, so on a transactional adapter
like dbt-postgres they land or roll back together and no reader ever sees the gap. What is
genuinely adapter-specific is the transaction, not the statement count: an adapter that
auto-commits each statement gives you the window this row used to claim. Read the boundary in
`dbt/include/global_project/macros/materializations/models/incremental/incremental.sql`.

**A watermark answers "what changed". It does not answer "what is now in scope".** This is the
half of incremental design that a green run will never tell you about, and all three incremental
marts here had it wrong until 2026-09-06.

`fct_orders` admits a row when `created_at <= now()` — the fixture carries scheduled and
pre-ordered rows dated into the future, and an order becomes a fact when the **clock** passes it.
The clock does not touch `updated_at`. So an order created for next Tuesday and last updated last
March arrives on Tuesday carrying a watermark value far below the mart's maximum, is selected by
nothing, and stays missing until somebody updates it or you full-refresh. Measured on this
fixture: 5 orders became eligible within one day and **3 of them sat below the watermark**. The
run exits 0, every test passes, and nothing in the project asserts that the mart is complete.

The predicate therefore has two arms, and their union is the real change set:

```sql
{% if is_incremental() %}
    and (
        orders.updated_at > (select coalesce(max(updated_at), '1900-01-01') from {{ this }})
        or not exists (select 1 from {{ this }} as prev where prev.order_id = orders.order_id)
    )
{% endif %}
```

`not exists` rather than `not in`: `not in` against a subquery that can yield NULL evaluates to
NULL for every row and quietly selects nothing. `fct_order_items` carries the same pair with a
composite probe.

`fct_daily_sales` is the same lesson one level up. A roll-up watermarked on its own
`max(sales_day)` can never revisit an older day, so a correction to an eighteen-month-old order
updates `fct_orders` and never reaches the aggregate — measured at **314.56 in the roll-up
against 423.06 in its parent**, both models green. It now carries `source_built_at`, a high-water
mark over `fct_orders.dbt_updated_at`, and rebuilds every day holding a parent row newer than it.
Keeping the mark in the target rather than reading `max(fct_orders.dbt_updated_at)` at run time is
what survives an unusual run order: build `fct_orders` twice without building the roll-up in
between and a run-time max sees only the second generation, losing the day the first one touched.

That column is new, and `on_schema_change: ignore` means an already-built table will not grow it —
see [Troubleshooting](#troubleshooting) for the one-line fix, and
[RELEASE-NOTES §13](RELEASE-NOTES-1.11.md) for the full account.

`dbt-postgres` publishes `merge` as a valid strategy on every server version and emits `MERGE`
unconditionally, so on Postgres 14 the run dies with `syntax error at or near "merge"` rather
than degrading to something that works. Only the **unnamed** default strategy degrades, and not
to `merge`'s semantics: `delete+insert` when the model sets a `unique_key`, `append` when it
does not. The failure is also delayed — `fct_order_items` is created by `CREATE TABLE AS` on the
first `--full-refresh` and only takes the incremental path on the next run, so a first build
that looks nearly green is not evidence the strategy is supported.

The two cues an exam item usually turns on: **is any historical row ever updated?** (no → `append`) and **is the natural unit of work a time period rather than a set of keys?** (yes → `microbatch`).

`fct_audit_events` also sets `full_refresh: false`, which is worth knowing before it surprises you: if you change what `stg_audit_events` selects, `--full-refresh` will **not** rebuild the downstream table. Drop the relation and re-run.

### State selection

All of these need the baseline from [step 5](#5--run-a-slim-ci-build) — `bash scripts/save-baseline.sh --rebase`.

```bash
dbt ls --select state:modified   --state ./prior-artifacts     # 8
dbt ls --select state:new        --state ./prior-artifacts     # 1
dbt ls --select state:modified+  --state ./prior-artifacts --resource-type model
```

Then the sub-methods, which is where the detail lives:

```bash
dbt ls --select state:modified.body    --state ./prior-artifacts   # the real code change
dbt ls --select state:modified.configs --state ./prior-artifacts
dbt ls --select state:modified.macros  --state ./prior-artifacts   # No nodes selected!
```

Against this baseline, only `.body` isolates the actual SQL change to `stg_products`. The new singular test shows up under **five of the six** sub-methods, because a node absent from the baseline counts as modified under all of them — `state:modified` always includes `state:new`. And `.macros` selects nothing, because nothing about the macros changed.

Now the same selector twice, with one flag moved:

```bash
dbt ls --select state:modified --state ./prior-artifacts                            # 8
dbt ls --select state:modified --state ./prior-artifacts --indirect-selection empty # 2
```

Same baseline, same selector, four different answers depending on the mode: `eager` (the default) 8, `cautious` 7, `buildable` 7, `empty` 2. Only two nodes really changed; under `eager` the six generic tests attached to `stg_products` come along because their parent was selected. If a node count from a `state:` selector ever surprises you, this is usually why.

### Defer, and which relation wins

```bash
dbt clone --target ci --state ./prior-artifacts --select fct_orders   # lands as a VIEW on Postgres

dbt compile --target ci --select fct_daily_sales --defer --state ./prior-artifacts
#   -> ref('fct_orders') resolves to "dbtae"."ci"."fct_orders"    (local wins — the default)

dbt compile --target ci --select fct_daily_sales --defer --state ./prior-artifacts --favor-state
#   -> ref('fct_orders') resolves to "dbtae"."dev"."fct_orders"   (deferred wins)
```

By default, when a referenced node exists in both the current target and the prior state, dbt uses the current target's. `--favor-state` flips that for unselected refs. This is exactly why `scripts/slim-ci.sh` insists on an empty `ci` schema: leftovers from an earlier run silently defeat the demo — the build looks slim but is reading last week's tables.

### Docs, freshness, source state

```bash
dbt source freshness                      # 5 PASS (audit_events sets freshness: null and is skipped)
dbt docs generate && dbt docs serve --port 8080
```

Both freshness outcomes are reachable on demand, without waiting:

```bash
psql -h postgres -U dbt_developer -d dbtae -f scripts/force_stale.sql
dbt source freshness                      # 5 ERROR STALE, exit 1
psql -h postgres -U dbt_developer -d dbtae -f scripts/restore_freshness.sql
dbt source freshness                      # 5 PASS again
```

`source_status:fresher+` needs all five steps below. Skipping the mutation or the second `dbt source freshness` leaves the two `sources.json` files identical, and the selector correctly reports `No nodes selected!`:

```bash
dbt source freshness                                    # 1. writes target/sources.json
bash scripts/save-baseline.sh                           # 2. freeze it as the baseline
psql -h postgres -U dbt_developer -d dbtae -f scripts/rotate_loaded_at.sql   # 3. mutate loaded_at
dbt source freshness                                    # 4. re-measure
dbt build --select source_status:fresher+ --state ./prior-artifacts          # 5. select
```

Note that step 2 overwrites `prior-artifacts/` with a snapshot of the current state, which is what this demo needs and what the `state:` demos above must not have. Re-run `bash scripts/save-baseline.sh --rebase` afterwards to get the teaching baseline back.

### Put the warehouse back

Every demo above writes somewhere, and three of those writes a rebuild cannot undo: the `UPDATE`s
that `force_stale.sql`, `rotate_loaded_at.sql` and `mutate-customers.sql` make to the **source**
tables, the **history** a snapshot accumulates (re-running a snapshot adds a version; it cannot
remove one), and the **schemas** dbt leaves behind for every target you have ever tried. Practise
for an afternoon and you are no longer looking at the dataset this README describes.

```bash
bash scripts/reset-warehouse.sh              # raw data + this project's schemas, then rebuild
bash scripts/reset-warehouse.sh --raw-only   # only put raw_ecom / raw_ref back
bash scripts/reset-warehouse.sh --deep       # also drop schemas this project did not create
```

It reloads `raw_ecom` and `raw_ref` from `data-seed/*.csv` — the same CSVs and the same DDL that
`db-init/` uses on first boot — drops the schemas `dbt ls` says this project writes to, and
rebuilds. It asks before it does any of that, it counts every row it loads against the CSV that
supplied it, and it never touches your repo files: `git restore .` is what puts an edited exercise
back.

**You cannot get this by restarting the container.** Postgres runs
`/docker-entrypoint-initdb.d` only when the data directory is empty, so `db-init/` does not run
again on a restart — before this script, the only complete reset was deleting the volume.

**And do not try to do it by copying Postgres's data files.** A copy taken from a running server
is torn rather than consistent, which is why `pg_dump` and `pg_basebackup` exist; doing it safely
means stopping the container for every save and every restore, and what you get is opaque,
tied to the PostgreSQL version that wrote it, and far larger than the ~20,000 rows it encodes.
The plain-text CSVs are already the source of truth. If you do want a byte-level rollback, take
it one level up — stop the stack, `docker volume rm` the Postgres volume, start it again, and
`db-init/` replays from scratch. That is `--deep`, slower.

### Operations / debugging

```bash
dbt run-operation grant_select --args '{schema: dev, role: bi_reader, dry_run: true}'
dbt run-operation codegen.generate_source --args '{schema_name: raw_ecom}'

dbt --debug run --select stg_orders
dbt --warn-error run

dbt compile --select resource_type:analysis    # the audit_helper relation diff
cat target/compiled/dbtae_companion/models/marts/fct_orders.sql
```

`dbt --warn-error run` exits **2** here, on purpose. It escalates the one warning this project emits on every parse: `fct_segment_activity` refs `dim_customer_segments.v1`, and v1 carries a `deprecation_date`, so dbt advises that the reference is slated for deprecation. That advisory fires because the version *has* a deprecation date — the date itself is in the future. `--warn-error` is a blunt global lever: it turns every warning into an error, which is what makes it useful in CI and painful everywhere else.

---

## Stack

| Component | Pinned version |
|---|---|
| Python | 3.11 |
| dbt-core | 1.11.14 |
| dbt-postgres | 1.11.0 |
| Postgres | 15 (required for native `MERGE`) |

Exact pins in [`requirements.txt`](requirements.txt) and [`packages.yml`](packages.yml). Upgrade guidance: [dbt migration guide](https://docs.getdbt.com/docs/dbt-versions/core-upgrade).

**Why dbt 1.11?** The current study guide states the exam supports dbt Core 1.11, so the repo pins it. That version is what makes the newest assessed topics runnable here rather than read-only: microbatch incremental models, YAML-defined snapshots, `hard_deletes`, and `--sample`. (`--empty` is older — it simply had no fixture here until this round.) Postgres 15 is still required for the native `MERGE` strategy.

What the upgrade changed, feature by feature, is in [RELEASE-NOTES-1.11.md](RELEASE-NOTES-1.11.md).

---

## What this repo can't demonstrate

These are two different lists, and conflating them makes the repo look like it is failing to cover assessed material when it isn't.

**On the exam, but adapter-blocked.** Read about them; you can't run them here.

- **Python models** — Snowflake / Databricks / BigQuery only
- **Zero-copy `dbt clone` semantics** — the command runs and produces pointer-view clones on Postgres, so `--state` selection, the target schema and the fallback are all observable; what can't be shown is a divergent write to a clone, which is a Snowflake / Databricks-Delta storage primitive
- **Metadata-based source freshness** — a source with thresholds but no `loaded_at_field` errors here with `The configured adapter does not support metadata-based freshness`. Snowflake and BigQuery (`dbt-bigquery` 1.7.3+) read it from warehouse metadata, and the reference lists Redshift too; **Databricks support is qualified as the dbt Fusion engine**, so it is not something you get on Core by swapping the adapter. Postgres has no metadata route at all
- **`PropertyMovedToConfigDeprecation` warnings** — the pre-1.10 top-level shapes (source `freshness:` / `loaded_at_field:`, exposure `tags:` / `meta:`) still **bind** here and are hoisted into `config`, so the behaviour is fully observable; only the *warning* is missing. dbt runs jsonschema property validation on bigquery, databricks, redshift and snowflake alone. Same rule hides the rejection of an unknown `owner:` sub-field on an exposure, which parses clean here

Everything else the exam names, this repo runs.

**Not on the current exam outline at all.** Absent here because they are out of scope, not because Postgres is in the way:

- **`incremental_strategy: insert_overwrite`** — partition-aware adapters only, and not named on the outline
- **dbt Cloud / dbt Studio surfaces** — jobs, environments, scheduler, the Studio IDE. The current study guide names no dbt Cloud surface
- **Semantic Layer / MetricFlow / saved queries**, and **dbt Catalog / Explorer** — explicitly out of scope
- **dbt Mesh** — model access and groups *are* in scope and are covered here; cross-project `ref()` needs two projects
- **Delta Lake and Unity Catalog features** — `tblproperties`, CDF, deletion vectors, column masks, multi-catalog nesting

For anything on either list, consult the [official dbt docs](https://docs.getdbt.com/docs). Rationale per item in [REPO-COVERAGE.md](REPO-COVERAGE.md).

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| *Reopen in Container* prompts **"Do you want to install Docker in WSL?"** | Docker Desktop not installed, or not running, or its WSL integration is off | Click **Cancel**. Install / start Docker Desktop (see [Prerequisites](#prerequisites)); on Windows also enable WSL 2 integration in Docker Desktop → Settings → Resources → WSL integration |
| `dbt debug` says connection refused | Postgres container not ready yet | Wait ~5s after container start; rerun |
| `Runtime Error / This version of dbt is not supported with the 'dbtae_companion' package`, exit 2, before anything runs | The installed dbt sits outside `require-dbt-version: [">=1.11.0", "<1.12.0"]` — a bare `pip install dbt-core` takes the newest release, which is already past 1.12 | `pip install -r requirements.txt`. The devcontainer does this for you (`Dockerfile` and `post-create.sh` both install from it); the exposure is a hand-rolled install |
| `Compilation Error ... two schema.yml entries` | Copied a broken YAML example into `models/` and didn't clean up | `rm -rf models/_tmp_broken/ macros/_tmp_broken/` (neither is gitignored, so they also show up as untracked junk) |
| `relation does not exist` on first run | Forgot `dbt seed` before `dbt run` | Run `dbt build` instead — it handles ordering |
| `state:modified+` selects 0 nodes | No baseline, or a baseline identical to your working tree | `bash scripts/save-baseline.sh --rebase` — it builds the baseline from the committed preimage, so there is a delta to select. Plain `save-baseline.sh` snapshots the *current* state, which by definition selects nothing until you then change something |
| Slim CI looks slim but the numbers are wrong | The `ci` schema still holds relations from an earlier run, and dbt prefers a local relation over a deferred one | Drop `ci`, `ci_snapshots`, `ci_reference`, `ci_dbt_test__audit` (see [step 5](#5--run-a-slim-ci-build)), or add `--favor-state` |
| `[WARNING]` on every run about `dim_customer_segments.v1` | Intentional. `fct_segment_activity` refs v1, and v1 declares a `deprecation_date`, so dbt advises the consumer that the version is slated for deprecation and points at v2 | Ignore it — it is the feature being taught. `dbt --warn-error run` escalates it to a build failure, which is the drill. It is not a "past date" warning and there is no date to fix |
| `column "source_built_at" does not exist` from `fct_daily_sales` | Your warehouse was built before 2026-09-06. That model gained a `source_built_at` high-water column, and its `on_schema_change: ignore` — required, because an incremental model with a contract may only use `append_new_columns` or `fail` — does not add columns to an existing table | `dbt run --select fct_daily_sales --full-refresh`, once. `bash scripts/reset-warehouse.sh` also covers it. A fresh clone never sees this, because a first build is a full build. Background: [RELEASE-NOTES §13](RELEASE-NOTES-1.11.md) |
| `dbt deps` warns about `metaplane/dbt_expectations` updates | Newer versions available; current pin is fine | Bump `packages.yml` if you want the latest |

---

## Contributing

Issues and PRs welcome. A few ground rules:

- Every change must keep `dbt build --full-refresh` green — currently `Done. PASS=117 WARN=0 ERROR=0 SKIP=0 NO-OP=3 TOTAL=120`. Quote the summary line rather than a node count; the count moves whenever a test is added, and stale counts in prose are this repo's most-repaired defect
- Then run `python scripts/check_receipts.py`, which re-measures every receipt this documentation quotes — the build summaries, the badge, the `dbt ls` count, the exercise inventory — and names any that no longer agree. It exists because those numbers went stale in five files at once and nothing said so. Each of its rules reports how many places it bound, and a rule that binds nothing **fails**: a check watching zero lines reads as evidence while proving nothing
- Run `bash .devcontainer/_test_exercises.sh` too — 22 PASS / 0 FAIL. It asserts every exercise's exit code, failure layer and error string — and, for the cases that emit no error, the DAG edges or config the manifest actually records — so it catches a dbt upgrade that changes a message the docs quote or moves an edge the docs claim
- The exam targets dbt Core 1.11; new models may use any 1.11 feature. Flag anything that needs a newer version, and anything Postgres cannot demonstrate, in `REPO-COVERAGE.md`
- Keep the project credential-free — real connection details belong in `~/.dbt/profiles.yml`, not the repo
- Don't put row counts, or anything else that drifts with wall-clock time, into prose. The fixture is generated relative to an anchor date and runs several years forward; several marts filter on `now()`, so their row counts change daily. Describe the shape instead
- The `exercises/` tree is invisible to dbt because it sits outside every `*-paths` entry in `dbt_project.yml` — that, not `.dbtignore`, is what keeps it out of the build (the `.dbtignore` line is a second guard for the day someone widens `model-paths`). Don't move broken examples into `models/` permanently, and don't leave `models/_tmp_broken/` behind: it is not in `.gitignore`

## License

MIT — see [LICENSE](LICENSE).

## Credits

- Built against the current [official dbt Analytics Engineer Certification](https://www.getdbt.com/certifications/analytics-engineer-certification-exam) study guide
- Uses open-source packages from [dbt Labs](https://github.com/dbt-labs) and [Metaplane](https://github.com/metaplane/dbt-expectations)
- Certification blueprint and concept coverage derived from the [official dbt documentation](https://docs.getdbt.com/docs)

---

<sub>This repo is an educational companion and is not affiliated with or endorsed by dbt Labs.</sub>
