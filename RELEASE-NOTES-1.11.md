# Release notes — dbt Core 1.11

This companion project moved from **dbt Core 1.8.9 to 1.11.14** (and `dbt-postgres` 1.8.2 to
1.11.0). The move was driven by the certification exam: the current study guide states the exam
supports dbt Core 1.11, and several newly-assessed topics simply cannot run below it.

Everything below was executed against Postgres 15.17, not inferred from release notes.

## The measured final state

```
Done. PASS=117 WARN=0 ERROR=0 SKIP=0 NO-OP=3 TOTAL=120
```

Exit code 0, and identical for `dbt build` and `dbt build --full-refresh`. Measured 2026-08-31.

**Quote that line, not a node count.** `TOTAL=120` is `3 exposures + 5 incremental models +
1 materialized view + 2 project hooks + 2 seeds + 3 snapshots + 6 table models + 89 data tests +
3 unit tests + 6 view models`. The arithmetic you can do from the file tree gives a different
number (the manifest has 116 nodes; `dbt ls` offers 125), and a hardcoded count in prose has
already gone stale three times in this repo's history — which is why
`python scripts/check_receipts.py` now re-measures every one of these numbers and diffs them
against the docs.

**Zero deprecations, and exactly one warning.** `grep -ic "deprecated functionality"` over a full
build log returns `0`. But every parsing command also prints one `[WARNING]`:

```
[WARNING]: While compiling 'fct_segment_activity': Found a reference to dim_customer_segments.v1,
which is slated for deprecation on '2027-12-31T00:00:00+00:00'. A new version of
'dim_customer_segments' is available.
```

That warning is **deliberate and permanent**. `dim_customer_segments` v1 carries a future
`deprecation_date`, and `fct_segment_activity` refs v1 on purpose, so the upcoming-reference
advisory is the fixture — it is what makes `dbt --warn-error` fail on this project, which is a
drill. `WARN=0` in the `Done.` line counts **test** warnings only; it says nothing about log
warnings. The honest summary of this repo is "0 errors, 0 deprecations, and one warning by
design". Earlier drafts of this file said "0 warnings", which was wrong.

---

## 1. Why this wasn't optional

Three topics the current blueprint names cannot run on the version this project was pinned to:

| Topic | Why 1.8 could not run it |
|---|---|
| Microbatch incremental models | `incremental_strategy='microbatch'` and the `event_time` / `begin` / `batch_size` configs did not exist |
| Snapshots defined in YAML | `snapshots:` in a YAML file was not a parseable resource; snapshots had to be `{% snapshot %}` blocks |
| `--sample` / sample mode | the flag did not exist |

`--empty` and the `flags:` block are a different case: both were runnable before the upgrade, but
this project had no fixture for either. It does now. (They are described in §6 without a version
attribution on purpose — `README.md` and an earlier draft of this file disagreed about whether
`--empty` was a 1.11 arrival, and the useful fact is what it does, not which release shipped it.)

## 2. What you must change in your own clone

```bash
git pull
pip install -r requirements.txt         # dbt-core 1.11.14, dbt-postgres 1.11.0
dbt deps --upgrade                      # regenerates package-lock.yml
dbt build --full-refresh
bash scripts/save-baseline.sh --rebase   # REQUIRED — see §10
```

The `--full-refresh` is not optional in this round either: `fct_daily_sales` gained a column, and
its `on_schema_change: ignore` will not add one on an incremental run. §13 has the error you get
if you skip it.

Note the `--rebase`. A bare `bash scripts/save-baseline.sh` still works, but it snapshots the
state you are already in, so every `state:` selector then returns nothing. §10 explains why.

If you use the devcontainer, **rebuild the image without cache**. `Dockerfile` and
`post-create.sh` both `pip install`, so a cached layer can leave two dbt versions resolvable
on `PATH`.

## 3. Generic-test arguments — a deprecation, not a breaking change

Arguments to a generic test now belong under an `arguments:` key. The project sets
`require_generic_test_arguments_property: true` in `dbt_project.yml`, and **17 call sites** were
migrated — 7 in `_marts__models.yml`, 6 in `_staging__models.yml`, 4 in `sources.yml`. `config:`
blocks stay at the top level; only test arguments move.

```yaml
# older flat form                   # current form
- relationships:                    - relationships:
    to: ref('country_codes')            arguments:
    field: country_code                   to: ref('country_codes')
                                          field: country_code
```

**The flat form still works.** An earlier draft of this file headed this section "Breaking
change", which overstates it, and that is the kind of thing a certification reader carries into
an exam. Read `dbt/parser/generic_test_builders.py:237-268` in the installed package: with the
flag on, dbt pops `arguments`, merges it over the flat keys
(`test_args = {**test_args, **arguments}`), and — if there are un-nested keys and no `arguments`
block — raises `missing-arguments-property-in-generic-test-deprecation`. A deprecation warning,
not a parse error. The migration is worth doing because the deprecation is a promise about a
future release and because the docs teach the nested form; it is not something that stops your
project building today. See `/reference/global-configs/behavior-changes` for how behaviour flags
escalate over releases.

## 4. Snapshots — the genuinely breaking change

### `target_schema:` → `schema:` — this relocates your snapshots

Not a rename. `target_schema` **bypassed** `generate_schema_name` and hard-coded one location
for every environment. `schema` routes through it, which is the point: snapshots become
environment-aware.

Because this project overrides `generate_schema_name` to prefix the target name in dev/ci, the
snapshots moved from `snapshots` to **`dev_snapshots`**. Your old tables are orphaned, not
migrated. Drop them once you're satisfied:

```sql
DROP SCHEMA IF EXISTS snapshots CASCADE;
```

### `invalidate_hard_deletes` → `hard_deletes`

| Old | New |
|---|---|
| `invalidate_hard_deletes=false` | `hard_deletes='ignore'` (the default) |
| `invalidate_hard_deletes=true` | `hard_deletes='invalidate'` |
| — | `hard_deletes='new_record'` |

`snp_products_check` now uses `new_record`, which adds a **`dbt_is_deleted`** column.
`snp_customers_timestamp` stays on `ignore` so the two can be compared side by side.

### `dbt_valid_to_current`

`snp_products_check` sets `dbt_valid_to_current="'9999-12-31'::timestamp"`, so current rows
carry a sentinel instead of `NULL`. Compare with `snp_customers_timestamp`, which keeps the
default `NULL`. This decides whether your downstream predicates need a NULL guard — and note
that `where dbt_valid_to is null` returns **nothing** against a snapshot with a sentinel.

### A YAML-defined snapshot — `snp_products_yaml`

`snapshots/_snapshots.yml` declares `snp_products_yaml` over
`relation: source('raw_ecom', 'product_catalog')`. The other two snapshots stay as SQL blocks
deliberately, so the project demonstrates both forms.

**Know the trade-off:** a YAML snapshot takes a `relation:`, not a query. It cannot project,
filter or alias columns. Whatever the relation exposes is what the snapshot captures — here, all
nine raw columns including the un-aliased `name`, where the SQL form captures six with
`name as product_name`.

**And know the hazard that follows from it, because it is the most instructive fact in this whole
upgrade.** `raw_ecom.product_catalog` carries two operational columns: `loaded_at` (when the ETL
wrote the row) and `updated_at` (when the source system last touched it). Under `check_cols: all`
those become change-detection inputs, so a re-load that changed nothing a human would call a
change still mints a new SCD2 version. This is not hypothetical here — `scripts/force_stale.sql`,
`scripts/restore_freshness.sql` and `scripts/rotate_loaded_at.sql` are three shipped demos that
move `loaded_at`. Measured, by flipping the config and running `dbt snapshot` after a
`loaded_at`-only change to 50 product rows:

```
--- shipped config (explicit check_cols list) ---
snp_products_yaml  | 50 rows      (unchanged — correct)

--- same change, check_cols temporarily flipped to `all` ---
 total_rows | closed_versions
        100 |              50    (50 spurious SCD2 versions from a load timestamp)
```

So the two forms carry two different configs on purpose:

| Form | File | `check_cols` | Why |
|---|---|---|---|
| YAML `relation:` | `snapshots/_snapshots.yml` | explicit list of 5 | cannot project, so the raw relation's timestamps are unavoidable and must be excluded by naming what counts instead |
| SQL block | `snapshots/snp_products_check.sql` | `all` | the SELECT projects 6 business columns and drops the timestamps, so "all" means all six things a human would call a change |

**`check_cols: all` is a statement about the projection, not about the table.** It is safe
exactly when you own the shape of what you are snapshotting. Point it at a raw relation with an
audit or load timestamp and every re-load mints a version. The usual textbook warnings — a
rename, a cast, a whitespace change — name the rarest triggers; the one that actually fires in
production is `loaded_at`.

## 5. Source and exposure properties moved under `config:`

`sources.yml` now nests `loaded_at_field` and `freshness` under `config:`, at both source and
table level, and `exposures.yml` nests `tags` and `meta` the same way.

**dbt 1.11 does not require this.** The old top-level form parses with no deprecation warning
whatsoever — that was verified, not assumed. The reason for the change is that the current docs
*teach* the nested form and describe the top-level form as "still supported… discouraged"; for
exposures, the docs show no legacy fallback at all.

A project that teaches the discouraged form is teaching against the documentation the exam is
drawn from, so the repo now demonstrates the recommended shape. Table-level opt-out still works
unchanged as `config: {freshness: null}`.

```yaml
# before                          # after
loaded_at_field: loaded_at        config:
freshness:                          loaded_at_field: loaded_at
  warn_after: {...}                 freshness:
                                      warn_after: {...}
```

## 6. New capability fixtures

### Microbatch — `models/marts/fct_orders_microbatch.sql`

Monthly batches, `lookback=1`, and `begin=var('start_date')` — which reads `2025-01-09` from
`dbt_project.yml`, the first business date the fixture covers. The model body has **no
`is_incremental()` guard and no WHERE clause**: dbt filters `ref('stg_orders')` per batch using
the `event_time` declared upstream.

**Do not quote a batch count.** dbt builds one batch per month from `begin` up to *now*, so the
number grows by one every month with no change to the SQL — which is itself the thing to watch:
re-run this model next month and a new batch appears. Re-anchoring the fixture means editing
`start_date` in one place; see `data-seed/GENERATED.md`. Note the other end of the window too:
the fixture deliberately contains forward-dated orders, and microbatch simply does not process
them until their batch's time arrives.

> **Adapter gotcha, verified the hard way — and it is `MERGE`, not delete+insert.**
> `postgres__get_incremental_microbatch_sql` dispatches to `get_incremental_merge_sql`, and
> `logs/dbt.log` shows `merge into "dbtae"."dev"."fct_orders_microbatch" as DBT_INTERNAL_DEST`
> once per batch. That is why Postgres 15+ is required and why **`unique_key` is mandatory**.
> Omit it and every batch after the first fails with
> `dbt-postgres 'microbatch' requires a unique_key config`. Batch 1 still succeeds, because a
> full refresh creates the relation without taking the incremental path — so "it built once" is a
> false positive. Adapters with native partition replacement (BigQuery, Databricks) replace the
> partition instead and do not need the key.
>
> An earlier draft of this file said dbt-postgres implements microbatch over delete+insert. It
> does not.

### `event_time` — on `stg_orders` and on the `raw_ecom.orders` source

Required by both microbatch and `--sample`.

> **`--sample` fails open.** If the relation being sampled does not declare `event_time`, the
> command still succeeds, still reports OK, and quietly processes the **full** dataset. Setting
> `event_time` on the model but not the source was enough to make `--sample` silently return
> every row of `stg_orders` instead of the requested window.

```bash
dbt run --target ci --select stg_orders --sample='{"start": "2026-01-01", "end": "2026-03-01"}'
# 175 rows — a window inside the committed fixture
```

**Pick your window from the fixture, not from habit.** The fixture's business-timestamp window is
**2025-01-09 → 2028-09-30**; `data-seed/GENERATED.md` is authoritative. An earlier draft of this
file used a 2024 window — against the current fixture that command exits 0 and returns **zero
rows**, which is the exact "fails open" trap the paragraph above warns about, firing on its own
example. A relative window works too and cannot rot the same way: `--sample '3 days'` returned
9 rows against the committed fixture on the measurement date, and that number moves with the
calendar.

One caveat, inherent rather than a bug: `dbt build --sample` exits 1 on
`relationships_stg_order_items_order_id__order_id__ref_stg_orders_`. Only `stg_orders` can
declare `event_time` — the raw line-item table carries no business timestamp — so sampling
orphans every line item. `dbt run --sample` is clean, and
`dbt build --sample '3 days' --exclude relationships_stg_order_items_order_id__order_id__ref_stg_orders_`
completes successfully.

### `--empty`

```bash
dbt build --target ci --empty --full-refresh
# Done. PASS=117 WARN=0 ERROR=0 SKIP=0 NO-OP=3 TOTAL=120
```

Builds every relation with its full column list and zero rows.

> **What a green `--empty` run does not prove.** Data tests pass **vacuously** on empty
> relations — `unique`, `not_null`, `relationships` and `accepted_values` have nothing to fail
> on. It is a compile-and-schema gate, not a data gate. `--empty` also does not exempt a model
> from needing its upstreams to exist; it limits input *rows*, not input *dependencies*.

### `flags:` block in `dbt_project.yml`

Records the behaviour-flag decisions explicitly. All four flags in the block —
`require_generic_test_arguments_property`, `source_freshness_run_project_hooks`,
`require_resource_names_without_spaces` and
`require_explicit_package_overrides_for_builtin_materializations` — already default to `True` at
this version (`dbt/contracts/project.py:358-368` in the installed package), so the block changes
nothing at runtime. That is the point. It documents intent, and it is where you opt into a flag
early when one is introduced but not yet default.

## 7. The fixture was re-anchored so it cannot decay

A fixture whose newest row sits in the past turns every wall-clock filter in the project into
zero rows — and zero rows still pass `not_null` and `unique`, so a decayed project goes green
while teaching nothing. That was happening here.

`scripts/generate_data.py` now writes all six CSVs from a single anchor date (**2026-09-01**),
producing a business-timestamp window of **2025-01-09 → 2028-09-30** and a newest `loaded_at`
roughly two years ahead of the anchor, so `dbt source freshness` passes on a fresh clone for the
whole runway. Every calendar day in the window carries at least two orders and at least one audit
event, so no `--sample` window of any length comes back empty. The generator carries a
**self-check that refuses to write a fixture which is already decaying**, and
`data-seed/GENERATED.md` records the anchor, the window, the row counts and the regeneration
command.

Two consequences worth knowing:

- **`fct_orders` filters future-dated orders at the mart boundary** (`created_at <=
  current_timestamp`), and the singular test `assert_no_future_orders` enforces that rule at mart
  level rather than at staging. `stg_orders` deliberately retains the forward-dated rows —
  staging renames and recasts, the mart adjudicates. `fct_order_items` does *not* apply the rule,
  so a scheduled order's lines can appear before the order does; the YAML says so rather than
  hiding it.
- **Row counts in `dev` now move with the calendar.** `fct_orders`, `fct_orders_microbatch`,
  `fct_daily_sales`, `fct_audit_events`, `stg_audit_events` and `mv_recent_orders` all track a
  window or a "so far" horizon. Do not assert a fixed number against them; say "about 1,800
  orders and growing", or state a measurement date.

`scripts/force_stale.sql` and `scripts/restore_freshness.sql` are new and exactly reversible. The
first shifts every `loaded_at` backwards so `dbt source freshness` returns `ERROR STALE` on all
five freshness-configured tables (exit 1); the second restores `max(loaded_at)` to the
generator's own value and freshness returns to 5 PASS (exit 0). Both directions were run.
Remember §4: running either of these and then `dbt snapshot` is precisely the scenario that would
mint spurious versions under `check_cols: all`.

## 8. Code corrections shipped in the same round

- **The dispatch override was dead code.** `macros/dbtae_companion__generate_surrogate_key.sql`
  defined `dbtae_companion__generate_surrogate_key`, a name `adapter.dispatch` never looks for:
  dispatch searches `<adapter>__<name>` then `default__<name>` within each package in its search
  order, never `<package>__<name>`. The macro was renamed to **`default__generate_surrogate_key`**
  and the file to `macros/generate_surrogate_key.sql`. The related point, which the repo also had
  backwards: dbt already searches your root project **first** by default, so the `dispatch:` block
  in `dbt_project.yml` is not what makes an override win — the macro's *name* is. The block is
  kept as a syntax exemplar, with a comment saying exactly that.
- **Surrogate-key documentation was false.** `models/docs/glossary.md` and
  `_staging__models.yml` stated surrogate keys were `sha256`. The macro emits **`md5`**.
  Corrected, and the substance rewritten: the override's real behavioural difference is
  *normalisation* (lower + trim before hashing), not the hash primitive. The three doc blocks in
  `models/docs/glossary.md` are now all referenced by `{{ doc() }}` — `surrogate_key_convention`
  and `pii_email` from both `_staging__models.yml` and `_marts__models.yml`, `order_status` from
  three places — so they render in `dbt docs`, and because `persist_docs` sets `relation: true`
  and `columns: true` they also land as warehouse column comments. When this correction was first
  written, `surrogate_key_convention` was referenced by no `{{ doc() }}` at all, and the
  justification given for the fix ("it renders into the generated docs site") was not yet true.
  It is now. (Cosmetic caveat: `glossary.md` has CRLF line endings, so the persisted comments
  carry a literal `\r`, visible in `psql \d+` output.)
- **The `check` constraint is on `price_cents`**, not `price_usd`. The warehouse says
  `CHECK ((price_cents >= 0))`.
- **The `foreign_key` constraint had to move.** The obvious placement —
  `fct_order_items.product_id` → `dim_products.product_id` — was implemented, verified in
  `pg_constraint`, and then found to be **non-durable**: `dbt-postgres` drops table models with
  `drop table ... cascade`, which silently drops every FK pointing at them, and `fct_order_items`
  is incremental so it is not rebuilt afterwards to get the constraint back. Net effect: FK
  present after `--full-refresh`, silently gone after the next plain `dbt build`. Reproduced
  directly. The constraint now lives on `fct_segment_activity.customer_id` →
  `dim_customer_segments` v1 — a table model built after its target on the same run, refing a
  contracted model with a `unique` constraint on the target column, which is what Postgres
  requires of an FK target. `fct_order_items` keeps its contract and its `relationships` test,
  and its YAML records why the FK is elsewhere.
- **`warn_if` / `error_if` are now wired into a real test.**
  `tests/assert_large_orders_within_review_tolerance.sql` demonstrates all three outcomes through
  a var. Note the trap the first attempt fell into: with `severity='warn'`, `error_if` is
  unreachable — `dbt/task/test.py:300` is `if severity == "ERROR" and result.should_error`, so a
  `warn` test can never escalate. The test ships with `severity='error'`.
- **Four incremental strategies, and all four `on_schema_change` values.** `append`
  (`fct_audit_events`, `sync_all_columns`), `delete+insert` (`fct_orders`, `append_new_columns`;
  `fct_daily_sales`, `ignore`), `merge` (`fct_order_items`, `fail`) and `microbatch`
  (`fct_orders_microbatch`, `ignore`). `fct_order_items` uses `fail` because it is contracted, and
  a contracted incremental model must set `append_new_columns` or `fail`. `insert_overwrite` is
  not demonstrated and cannot be on this adapter.
- **`dim_customer_segments` v1 `deprecation_date` rolled forward** to 2027-12-31. It had lapsed,
  so dbt emitted "has passed its deprecation date" on every run. Rolling it forward silenced
  *that* warning — it did **not** silence the upcoming-reference advisory described at the top of
  this file, which fires because a consumer refs a version that has a `deprecation_date` at all,
  regardless of whether that date is past or future. Set it to a past date yourself if you want
  to see the lapsed state.
- **`limit_data_in_dev` had a lower bound but no upper one.** A `>= current_date - N days` clause
  reads like a "last N days" filter and is not one against a fixture that carries forward-dated
  rows: it admitted the recent window *plus* the entire future. The upper bound
  `< current_date + interval '1 day'` was added, and the macro's own header records what each
  bound selects. **This moves your `dev` and `ci` row counts** for `stg_audit_events` and
  everything downstream of it — that is the change, not a regression you are seeing.
- **`dim_customers` now applies the same future-order rule as `fct_orders`** — `where created_at
  <= {{ dbt.current_timestamp() }}` over `stg_orders`. It reads staging directly, because
  `fct_orders` refs *it* for country enrichment and the reverse would be a cycle, so the rule is
  restated rather than inherited. Without it `latest_order_at` was the timestamp of a *scheduled*
  order, and the `dim_customer_segments` v2 recency bands called a dormant customer active. §7
  states the rule for `fct_orders`; it holds in both places. Your `latest_order_at` values and v2
  segment assignments move with this.
- **The `audit_helper` analysis compared a relation with itself.**
  `analyses/compare_fct_orders_versions.sql` passed `ref('fct_orders')` as both `a_relation` and
  `b_relation`, so `compare_relations` could only ever report a perfect match — a reconciliation
  that cannot report a difference. It now compares `fct_orders` against `fct_orders_microbatch`,
  two independently-materialised cuts of the same order stream, with `exclude_columns` scoping the
  comparison to the columns both project. The header also records that `--select analysis:<name>`
  is not a selector method (`resource_type:analysis` is).

## 9. The exercises were rebuilt

`exercises/` now holds **22 cases in 22 directories**, not twelve. The `.broken` suffix is gone,
`exercises/yaml/` was split into `yaml_indent/`, `yaml_wrong_type/` and `yaml_unknown_key/`, and
every case uses one consistent trigger flow: copy the case's files into `models/_tmp_broken/`,
run the stated command, then delete. The tree is invisible to dbt because it lives outside every
`*-paths` in `dbt_project.yml`; the `.dbtignore` entry is a second guard, not the mechanism.
`.devcontainer/README.md` documents the verification suite, and
`bash .devcontainer/_test_exercises.sh` asserts all 22 (exit 0, `22 PASS / 0 FAIL`).
`.devcontainer/_diag.sh` went in the same round — an ad-hoc `whoami` / `hostname` / `ls` shell
probe from before the suite existed. Nothing in the repo referenced it, and `dbt debug` answers
what it answered.

Two cases are worth calling out, because they contradict what you would expect:

- `constraint_missing_data_type` and `source_misresolved` fail at **run**, not at parse. `dbt
  parse` and `dbt compile` both exit 0 for each.
- `yaml_unknown_key` is a **silence fixture**. dbt gates YAML jsonschema validation to
  `{"bigquery", "databricks", "redshift", "snowflake"}` (`dbt/jsonschemas/jsonschemas.py`), so on
  Postgres an unknown YAML key produces no warning, no error, exit 0 — and is simply absent from
  `manifest.json`. A reader on Snowflake *will* see a warning. The manifest is the only portable
  check.

## 10. Regenerate your state baseline — and note where it lives

`prior-artifacts/` held a **mixed-vintage** set: a 1.11.14 `manifest.json` and `run_results.json`
alongside a `sources.json` and `catalog.json` still at **1.8.9**, dated months earlier. A baseline
assembled from different versions and different runs is not safely comparable, so `state:modified`
results were untrustworthy. `scripts/slim-ci.sh` and `scripts/clone-demo.sh` both depend on it.

**`prior-artifacts/` is gitignored** (`.gitignore:4`), so a fresh clone never receives it — you
must generate it. What ships instead is `scripts/baseline-preimage/`, which *is* tracked: a
`PREIMAGE` manifest plus the earlier version of `models/staging/stg_products.sql`, describing a
deliberate, realistic pull request between the baseline and HEAD (a value-neutral refactor to the
shared `cents_to_dollars()` macro, plus one new singular test). `PREIMAGE` carries a per-file
sha256 drift guard, so editing `stg_products.sql` without re-deriving the preimage aborts the
rebase instead of silently baselining a delta nobody designed.

```bash
bash scripts/save-baseline.sh --rebase
```

**Why a single `dbt build && cp -r target/` does not work.** The four state artifacts have four
different producers, and they clobber each other. Measured, by running each command and checking
whether `target/run_results.json` changed:

| Command | Rewrites `run_results.json`? |
|---|---|
| `dbt ls`, `dbt parse`, `dbt source freshness` | no (`source freshness` writes `sources.json`) |
| `dbt seed`, `dbt compile`, `dbt show`, `dbt run-operation`, `dbt clone` | **yes** |
| **`dbt docs generate`** | **yes** — 115 results, `which=generate` |

So `docs generate` — the only producer of `catalog.json` — destroys the build's
`run_results.json` on its way past. The script now runs each producer and copies its artifact out
immediately:

```
dbt build            -> cp manifest.json, run_results.json   (captured before anything clobbers it)
dbt source freshness -> cp sources.json
dbt docs generate    -> cp catalog.json
```

Earlier drafts of this file recommended
`dbt build --full-refresh && bash scripts/save-baseline.sh`, which regenerates neither
`sources.json` nor `catalog.json`, and is how the mixed-vintage baseline came about in the first
place.

The reader procedure in full. The `ci` schema must be empty first, because without
`--favor-state` dbt prefers an existing relation in the current target over the deferred one:

```bash
psql -c 'drop schema if exists ci cascade;'
psql -c 'drop schema if exists ci_snapshots cascade;'
psql -c 'drop schema if exists ci_reference cascade;'
psql -c 'drop schema if exists ci_dbt_test__audit cascade;'

bash scripts/save-baseline.sh --rebase

dbt ls --select state:modified --state ./prior-artifacts --resource-type model
dbt ls --select state:new      --state ./prior-artifacts
bash scripts/slim-ci.sh          # Done. PASS=17 ... TOTAL=18, and 3 relations land in ci
```

`bash scripts/save-baseline.sh` with no argument still snapshots the **current** state, for a
reader who wants to make their own edit and diff against it. It now prints a warning saying
`state:modified` will select nothing until you change something.

## 11. Package bumps

| Package | Was | Now |
|---|---|---|
| `dbt-labs/dbt_utils` | 1.3.3 | 1.4.1 |
| `metaplane/dbt_expectations` | 0.10.4 | 0.10.10 |
| `dbt-labs/audit_helper` | 0.12.1 | 0.14.0 |
| `dbt-labs/codegen` | 0.12.1 | 0.14.1 |
| `dbt_date` (transitive) | `calogica/dbt_date` 0.10.1 | **`godatadriven/dbt_date` 0.21.0** |

Verified against `package-lock.yml`. `dbt_date` changed namespace; staying on `calogica` raised
`PackageRedirectDeprecation`, and the bump clears it.

Note for `REPO-COVERAGE.md` readers: `microbatch` and `hard_deletes` moved from `skip` to `full`
in this round. `insert_overwrite`, Python models, and the Delta/Unity/dbt-platform rows remain
skipped — those are blocked by the **adapter**, not the version, and a 1.11 bump does not change
them.

## 12. Explicitly not done: dbt Fusion / Core 2.0

**Postgres is not a supported Fusion adapter.** Moving there is a re-platform decision, not an
upgrade, and it would cost this project the Postgres `MERGE` strategy, the materialized-view
demo, and the role/`GRANT` fixtures. The current study guide names no Fusion-only feature.

---

## 13. Model corrections, 2026-09-06 — and the one that needs a `--full-refresh`

A full re-review of the repo against a live warehouse found four defects in the models and tests
themselves. All four were silent: every run exited 0 and every test passed while the numbers were
wrong, which is the only kind of defect worth a section of its own.

- **`fct_orders` and `fct_order_items` were losing rows the clock made eligible.** Both marts cut
  on `created_at <= now()` and both selected incrementally on a watermark over `updated_at`. Those
  two rules do not compose. The fixture carries scheduled and pre-ordered rows dated into the
  future, so an order becomes a fact when the CLOCK passes it — and the clock does not touch
  `updated_at`. An order created for next Tuesday and last updated last March arrives on Tuesday
  with an `updated_at` far below the watermark, is selected by nothing, and stays missing until
  someone updates it or you `--full-refresh`. Measured 2026-09-06: **5 orders became eligible
  within one day, 3 of them below the watermark**; a full refresh at the same clock returned all
  five. The predicate now has two arms — the watermark for what CHANGED, and a `not exists`
  probe for what is ELIGIBLE BUT ABSENT — and their union is the real change set. Verified by
  making one future order eligible without touching its `updated_at`: it and its three lines now
  land on a plain incremental run, where before they landed on neither.
- **`fct_daily_sales` never saw a correction to an old order.** It selected
  `created_at >= max(sales_day)`, which watermarks a BUSINESS date to answer a question about
  CHANGE. Correct order 1 (dated 2025-01-09) at source, rebuild `fct_orders`, rebuild the roll-up,
  and the day still read **314.56 while its own parent summed to 423.06** — both runs green,
  every test passing, because the tests assert uniqueness and non-nullity of the roll-up and
  nothing asserts that it agrees with `fct_orders`. **This is the change that needs a
  `--full-refresh`; see below.**
- **The reconciliation test passed after an order lost every line.**
  `tests/assert_fct_orders_amount_matches_items.sql` inner-joined the two facts, so an order
  with no surviving lines was not compared at all. Delete every line of order 1, leave its
  total at 15996, and the test reported `PASS=3`, exit 0. It is a `left join` now, and **both**
  `coalesce`s are load-bearing:
  the one in the `where` selects the row, the one in the projection lets the custom `fail_calc`
  measure it — fix only the `where` and `abs(total - NULL)` is NULL, which
  `coalesce(sum(...), 0)` turns straight back into zero failures. It now returns `FAIL 15996`,
  the discrepancy in cents.
- **Source freshness checked a hardcoded schema.** `raw_ecom.product_catalog` sets
  `loaded_at_query`, which is raw SQL dbt does not resolve against the source — so it kept naming
  `raw_ecom.products` after `RAW_SCHEMA_ECOM` had moved the source elsewhere. Pointed at an
  alternate schema whose newest load was 2000-01-01, freshness still **passed on the original
  2028 timestamp**. The query now renders the same `env_var` expressions `database:` and `schema:`
  use, and the same test errors as it should.

### The one thing you must do in an existing clone

`fct_daily_sales` gained a column, **`source_built_at`** — the high-water mark it advances on
itself, holding the newest `fct_orders.dbt_updated_at` among the orders in that day. Any parent
row written since that mark, whether corrected, newly eligible or brand new, puts its whole day
back in the change set; `unique_key: sales_day` with `delete+insert` then replaces those days
outright. The mark is kept in the target rather than read from `max(fct_orders.dbt_updated_at)`
at run time on purpose: build `fct_orders` twice without building this model in between and a
run-time max sees only the second generation, silently losing the day the first one touched.

This model sets `on_schema_change: ignore`, which is not an oversight — the YAML's contract
argument turns on it, and an incremental model with a contract may only set `append_new_columns`
or `fail`. `ignore` means an already-built table does **not** grow the new column, so the next
incremental run reads a column that is not there:

```
Database Error in model fct_daily_sales (models/marts/fct_daily_sales.sql)
  column "source_built_at" does not exist
  LINE 25:     where dbt_updated_at > (select coalesce(max(source_built...
```

One command, once — and a fresh clone never meets it, because a first build is a full build:

```bash
dbt run --select fct_daily_sales --full-refresh
```

The `dbt build --full-refresh` in §2 already covers it, as does
`bash scripts/reset-warehouse.sh`. Nothing else in this round changes a relation's shape.

### And the receipts are checked now, not maintained

The same review found the build summary quoted as `PASS=116 … TOTAL=119` in five documents, the
badge, and a model description, long after the project had been building `PASS=117 … TOTAL=120` —
plus `21 exercises` against 22 on disk and `124 selectable nodes` against 125. Nothing was
watching, so nothing said so. `python scripts/check_receipts.py` now re-measures every command
whose summary this documentation quotes and diffs it against the prose, and each of its rules
reports how many places it bound — a rule that binds nothing **fails**, because a check watching
zero lines reads as evidence while proving nothing.

---

## 14. Errata — what earlier drafts of this file got wrong

These notes were written at the end of the upgrade and then measured. The corrections are
recorded rather than quietly overwritten, because anyone who read the earlier version is carrying
these claims, and because two of them are the kind of thing a certification reader would take
into an exam.

| Earlier claim | What is true |
|---|---|
| "112 passing nodes, 0 errors, **0 warnings**, 0 deprecations" | `PASS=117 … TOTAL=120`; 0 errors and 0 deprecations, but **one deliberate `[WARNING]` on every parsing command** — see the top of this file |
| "**Breaking change**: generic-test arguments" / "became mature in dbt 1.10.8" | A **deprecation**, not a break: the flat form still merges and builds (§3). The patch version was not verifiable offline and has been dropped |
| microbatch on dbt-postgres runs "over delete+insert" | It runs as **`MERGE`** (§6) |
| `--sample='{"start": "2024-01-01", "end": "2024-03-01"}'` "returns 121 rows" | That window is entirely outside the current fixture: exit 0, **0 rows**. Use a window inside 2025-01-09 → 2028-09-30 (§6) |
| `dbt build --full-refresh && bash scripts/save-baseline.sh` | Regenerates neither `sources.json` nor `catalog.json`; use `bash scripts/save-baseline.sh --rebase` (§10) |
| "`prior-artifacts/` held a 1.8.9 manifest" | It held a **mixed-vintage** set — 1.11.14 manifest and run_results, 1.8.9 sources and catalog (§10) |
| "the glossary block renders into the generated docs site" | It did not at the time — `surrogate_key_convention` was referenced by no `{{ doc() }}`. It is wired up now, so the claim holds today (§8) |
| the deprecation-date roll-forward silenced the warnings | It silenced the *lapsed* warning only; the upcoming-reference advisory still fires, by design (§8) |
| `snp_products_check_all`, and "`check_cols: all` over a whole relation is the case that loses nothing" | Renamed **`snp_products_yaml`**, and it uses an **explicit `check_cols` list**. `all` over a raw relation cost 50 spurious SCD2 versions in a measured test (§4) |
| "`--empty` … worked on 1.8" | Version attribution dropped; the useful fact is what it does (§1, §6) |
