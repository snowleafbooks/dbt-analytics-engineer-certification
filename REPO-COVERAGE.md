# REPO-COVERAGE.md

Build spec for this companion repo. Each row maps an exam concept to the repo artifact that
demonstrates it, and to a command that makes it observable. Readers run `dbt` against the
artifact; the repo stays credential-free and standalone.

Every command in this file is re-executed against the shipped tree whenever the document is
revised — last on **2026-09-02**, with dbt-core 1.11.14 / dbt-postgres 1.11.0 on Postgres 15.17.
Where a command does *not* work, works only with extra arguments, or needs the warehouse left in
a particular state first, the row says so rather than pretending. A row that says otherwise is a
bug in this file, not a quirk of your machine.

## Stack

- Python 3.11
- `dbt-core==1.11.14`, `dbt-postgres==1.11.0` — the version the current study guide names
- Postgres 15 (native `MERGE`, which the `merge` and `microbatch` strategies use here)
- Linux container (devcontainer), no Windows path assumptions

The repo targets **dbt Core 1.11** because that is the version the current certification study
guide supports. Everything the guide names is exercised here on dbt Core alone — unit tests,
YAML snapshots, microbatch, `--empty`, `--sample`, behaviour-change flags and YAML constraints
included. Two items are blocked by the *adapter*, not by dbt: Python models and zero-copy clone
semantics. Nothing is blocked by dbt Cloud, because the current guide names no dbt Cloud
surface at all.

## How to read this document

- **"Concept"** — the exam-relevant primitive, as named in the current study guide (dbt Core 1.11).
- **"Repo artifact"** — the file or block where the concept is exercised.
- **"Command"** — a verified CLI invocation. Commands assume repo root, an active profile, and
  a completed `dbt deps && dbt seed && dbt build`.
- **"Status"** —
  - `full` — runs end to end and shows the concept;
  - `partial` — present but with a documented caveat, or exercised only in part;
  - `skip` — not demonstrated here, with the reason stated.

An honest `partial` is preferred to an aspirational `full`. Several rows below are `partial`
precisely because measurement said so.

### Domain map

The current study guide has **seven** domains. Documentation was removed as a domain and the
two below it renumbered (old Topic 7 → 06, old Topic 8 → 07). This file follows the current
numbering throughout.

| # | Domain | Section here |
|---|---|---|
| 01 | Developing and optimizing dbt models | [Domain 1](#domain-1--developing-and-optimizing-dbt-models) |
| 02 | Managing dbt models governance | [Domain 2](#domain-2--managing-dbt-models-governance) |
| 03 | Debugging data modeling errors | [Domain 3](#domain-3--debugging-data-modeling-errors) |
| 04 | Troubleshooting and optimizing dbt pipelines | [Domain 4](#domain-4--troubleshooting-and-optimizing-dbt-pipelines) |
| 05 | Implementing dbt tests | [Domain 5](#domain-5--implementing-dbt-tests) |
| 06 | Implementing and maintaining external dependencies | [Domain 6](#domain-6--implementing-and-maintaining-external-dependencies) |
| 07 | Leveraging the dbt state | [Domain 7](#domain-7--leveraging-the-dbt-state) |

Documentation artifacts (doc blocks, descriptions, `persist_docs`, the docs site) are retained
and still run — they serve the `dbt docs` command bullet in Domain 01 and the exposures bullet
in Domain 06 — but they are no longer a domain of their own. They live in
[§1.13](#113-documentation-artifacts--retained-no-longer-its-own-domain).

### What a clean run looks like

```
Finished running 3 exposures, 5 incremental models, 1 materialized view model, 2 project hooks,
2 seeds, 3 snapshots, 6 table models, 89 data tests, 3 unit tests, 6 view models

Done. PASS=117 WARN=0 ERROR=0 SKIP=0 NO-OP=3 TOTAL=120
```

Quote the summary line, not a node count: the file-tree arithmetic does not reproduce
`TOTAL=120`, and the number moves whenever a test is added. Every parsing command also emits
exactly **one** `[WARNING]` — the deliberate `dim_customer_segments.v1` upcoming-deprecation
advisory (see [§3.5](#35-managing-dbt-behaviour-with-flags)). `WARN=0` counts *test* warnings only.

---

## Domain 1 — Developing and optimizing dbt models

### 1.1 Project scaffolding & configuration

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `dbt_project.yml` with `name`/`version`/`profile` | `dbt_project.yml` | `dbt parse` | full |
| `require-dbt-version` pin | `dbt_project.yml` (`[">=1.11.0", "<1.12.0"]`) | `dbt parse` after bumping dbt | full |
| Path keys (`model-paths`, `seed-paths`, … — all six listed explicitly) | `dbt_project.yml` | `dbt debug` | full |
| `clean-targets` | `dbt_project.yml` (`["target", "dbt_packages", "logs"]`) | `dbt clean` — removes `dbt_packages/` too, so re-run `dbt deps` after | full |
| Project-level `vars:` | `dbt_project.yml` (`start_date`, `force_test_fail`). Both are actually read: `start_date` is the `begin` of `fct_orders_microbatch`; `force_test_fail` gates a test | `dbt compile --select fct_orders_microbatch` | full |
| `var()` with a default, overridden at the CLI | `tests/assert_large_orders_within_review_tolerance.sql` (`var('large_order_review_usd', 1000)`) | `dbt test --select assert_large_orders_within_review_tolerance --vars '{large_order_review_usd: 500}'` | full |
| `on-run-start` / `on-run-end` hooks | `dbt_project.yml` (log on start; result-count log on end) | any `dbt run` — the two project hooks are 2 of the `TOTAL` | full |
| `pre_hook` / `post_hook` at model level | `models/marts/fct_orders.sql` (`post_hook=["analyze {{ this }}"]`) | `dbt run --select fct_orders` | full |
| `query-comment:` with a macro | `dbt_project.yml` + `macros/query_comment.sql` (JSON comment, `append: true`) | `dbt --debug compile --select stg_orders` — the comment is **trailing** (`append: true`) and appears only in the query log, never in `target/compiled/` or `target/run/` — it rides on the statement dbt sends, not on the SQL dbt writes to disk | full |
| `flags:` block in `dbt_project.yml` | `dbt_project.yml` — four behaviour-change flags | `dbt parse` — **no delta as shipped**: all four are set to the value 1.11 already defaults to, so the block records a decision rather than changing behaviour. Set one to `false` and two of the four change the output immediately. See [§3.5](#35-managing-dbt-behaviour-with-flags) | full |
| Config precedence: project `+config` vs inline `{{ config() }}` vs YAML `config:` | `models/staging/stg_customers.sql` sets `materialized='view'` and `tags` inline, coexisting with the project-level `staging: +materialized: view` / `+tags: ['staging']`; inline wins on a tie and would override the folder default if they differed. The YAML layer is in use too — `dim_products`, `dim_customer_segments`, `fct_orders` and others carry a `config:` block in `models/marts/_marts__models.yml` | `dbt compile --select stg_customers`, then inspect `target/compiled/` | full |
| `env_var()` | `profiles.yml.example` + `models/sources.yml` (`database: "{{ env_var('RAW_DATABASE', 'dbtae') }}"`) | `dbt debug` | full |
| `generate_schema_name` override | `macros/get_custom_schema.sql` — this is why seeds land in `dev_reference`, snapshots in `dev_snapshots`, and stored test failures in `dev_dbt_test__audit` | any `dbt run`, then `psql -c "\dn"` | full |

### 1.2 Models, `ref()`, and the DAG

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `ref()` between models | every `models/**/*.sql` except staging | `dbt ls --select +fct_orders` → 64 nodes | full |
| Staging → intermediate → marts layering | `models/staging/`, `models/intermediate/`, `models/marts/` | `dbt build` | full |
| `{{ this }}` self-reference | `models/marts/fct_daily_sales.sql` (incremental filter) | `dbt run --select fct_daily_sales` | full |
| `{{ target.name / schema / database }}` and `run_started_at` | `macros/audit_columns.sql`, called by `models/staging/stg_orders.sql` | `dbt compile --select stg_orders` | full |
| `adapter.dispatch()` (`default__` + `postgres__`) | `macros/date_trunc_day.sql`, called by `models/marts/fct_daily_sales.sql` | `dbt run --select fct_daily_sales` | full |
| Macro branching on `target.name` | `macros/limit_data_in_dev.sql`, called by `models/staging/stg_audit_events.sql` | `dbt compile --select stg_audit_events` | full |
| Circular dependency (counter-example) | `exercises/cyclic/` (A ↔ B) | copy the case into `models/_tmp_broken/`, then `dbt compile` → exit 2, `Found a cycle: model.dbtae_companion.A --> model.dbtae_companion.B`. Cycles surface at graph link, not parse | full |
| A hard-coded relation creates **no** DAG edge | `exercises/hardcoded_relation/` — `orders_hardcoded` reads `{{ target.schema }}.hc_upstream` instead of `ref()`. Interpolating `target.schema` resolves correctly in every environment and still registers nothing | copy the case in, `dbt parse`, then read the manifest: `orders_hardcoded.depends_on.nodes == []`. `dbt run --select orders_hardcoded` → exit 1, `relation "dev.hc_upstream" does not exist` — but only on a schema where nobody built the parent earlier, which is why the assertion is the manifest and not the error | full |
| `-- depends_on:` restores a hidden edge; `{# depends_on: #}` does not | `exercises/depends_on_comment/` — two models one character apart, both reading `dc_upstream` by hard-coded name. The **SQL** comment is rendered as Jinja before it is a comment, so the `ref()` executes; the **Jinja** comment is stripped without rendering | copy the case in, `dbt parse` → exit 0, then the manifest: `orders_via_sql_comment` → `['model.dbtae_companion.dc_upstream']`, `orders_via_jinja_comment` → `[]` | full |
| A `ref()` in an unrendered branch is invisible to the graph | `exercises/conditional_ref/` — one file, two `ref()`s, one `{% if var(...) %}`. Only the branch Jinja renders contributes an edge | copy the case in; `dbt parse` → parent `stg_orders`; `dbt parse --vars '{use_products: true}'` → parent `stg_products`. Same file, same commit, two graphs, no error either time. The same trap fires on `target.name`, `is_incremental()` and `execute` | full |

### 1.3 Sources and raw object dependencies

Source *freshness* is a Domain 06 bullet and lives in [§6.2](#62-source-freshness).

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `sources:` YAML at `(database, schema)` granularity | `models/sources.yml` — two sources sharing one database, different schemas (`raw_ecom`, `raw_ref`) | `dbt ls --resource-type source` → 6 tables | full |
| `source()` Jinja function | every `stg_*.sql` | `dbt compile --select staging` | full |
| `identifier:` override | `models/sources.yml` — `product_catalog` declares `identifier: products`, so the dbt-facing name differs from the warehouse table. Verifier: `.devcontainer/_verify_identifier.sh` | `dbt run --select stg_products` | full |
| `env_var()` inside source `database:` / `schema:` | `models/sources.yml` | `dbt debug` | full |
| `event_time:` on a source table | `models/sources.yml` (`orders`, `event_time: created_at`) — what makes `--sample` and downstream microbatch able to slice by time | `dbt parse` | full |
| Source-column tests (`unique`, `not_null`, `accepted_values`, `relationships`) | `models/sources.yml` | `dbt test --select "source:*"` | full |
| Diagnosing a *mis-pointed* source | `exercises/source_misresolved/` — a source whose `schema:` is omitted, so it resolves to a relation that does not exist | copy the case in, then `dbt run --select stg_orders_misresolved` → exit 1, `relation "ecom_landing.orders" does not exist`. Parse and compile are both **clean**: dbt never validates that a source exists | full |
| Seed vs source distinction | `seeds/` (reference data dbt owns); `models/sources.yml` points at `raw_ecom.*` / `raw_ref.*`, loaded by `db-init/` | `dbt ls --resource-type seed` and `dbt ls --resource-type source` | full |

### 1.4 Materializations

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `view` (default for staging) | `models/staging/*.sql` (6 models) | `dbt run --select staging` | full |
| `table` | `models/marts/dim_customers.sql` and five more | `dbt run --select dim_customers` | full |
| `ephemeral` | `models/intermediate/int_order_items_enriched.sql`, consumed by `fct_order_items` | `dbt compile --select fct_order_items`, then read the inlined CTE | full |
| `incremental` with `unique_key` + `is_incremental()` guard + `on_schema_change` | `models/marts/fct_orders.sql` (`unique_key='order_id'`, `on_schema_change='append_new_columns'`) | `dbt run --select fct_orders` twice | full |
| Composite `unique_key` | `models/marts/fct_order_items.sql` (`['order_id','line_no']`) | `dbt run --select fct_order_items` | full |
| All four `on_schema_change` values | `append_new_columns` (`fct_orders`), `ignore` (`fct_daily_sales`), `sync_all_columns` (`fct_audit_events`), `fail` (`fct_order_items`) | `dbt parse`, then read the four model headers | full |
| `incremental_strategy: append` | `models/marts/fct_audit_events.sql` | `dbt run --select fct_audit_events --full-refresh` | full |
| `incremental_strategy: delete+insert` | `models/marts/fct_orders.sql`, `models/marts/fct_daily_sales.sql` (the roll-up replaces whole `sales_day` keys, which is what lets it recompute a corrected day rather than append to it) | `dbt run --select fct_orders --full-refresh` | full |
| `incremental_strategy: merge` | `models/marts/fct_order_items.sql` (native `MERGE` on Postgres 15) | `dbt run --select fct_order_items` | full |
| `incremental_strategy: microbatch` | `models/marts/fct_orders_microbatch.sql` (`event_time='order_created_at'`, `begin=var('start_date')`, `batch_size='month'`, `lookback=1`, `unique_key='order_id'`). One batch per calendar month from `begin` to the current month, so the batch count grows by one every month — `Batch 21 of 21 … batch 2026-09` when this was last run. On dbt-postgres each batch executes as `merge into …`, which is *why* `unique_key` is mandatory here | `dbt run --select fct_orders_microbatch --full-refresh` | full |
| `incremental_strategy: insert_overwrite` | not demonstrated — partition-aware adapters only (BigQuery / Spark / Databricks) | — | skip (adapter-blocked) |
| `--full-refresh` | `models/marts/fct_orders.sql` | `dbt run --select fct_orders --full-refresh` | full |
| `full_refresh: false` config (protect an incremental from CLI full-refresh) | `models/marts/fct_audit_events.sql` | `dbt run --select fct_audit_events --full-refresh` — the model is **not** rebuilt. To reset it you must drop the table | full |
| `materialized_view` + `on_configuration_change: apply` | `models/marts/mv_recent_orders.sql`. Verifier: `.devcontainer/_mv_verify.sh` | `dbt run --select mv_recent_orders`, then `REFRESH MATERIALIZED VIEW dev.mv_recent_orders` to repopulate | full |
| Python models | not demonstrated — dbt-postgres has no Python runtime. Recall only: a `.py` file under `models/`, `def model(dbt, session)`, `dbt.ref()` vs Jinja `{{ ref() }}`, `dbt.config(packages=[…])`, `table`/`incremental` only | — | skip (adapter-blocked) |

### 1.5 Choosing an incremental strategy

The guide assesses *choosing* a strategy for a dataset's characteristics, not just configuring
one. Every row below has a working model in this repo.

| Dataset shape | Strategy | Model here | Adapter requirement |
|---|---|---|---|
| Append-only event stream: rows are never updated or deleted, and a monotonically ascending id or timestamp gives a safe watermark | `append` | `models/marts/fct_audit_events.sql` | none — every adapter. No `unique_key`; duplicates are your problem if the watermark is wrong |
| Late-arriving updates to a bounded recent window, where "replace the affected keys wholesale" is simpler to reason about than a row-by-row match | `delete+insert` | `models/marts/fct_orders.sql` | needs `unique_key`. **Two statements, one transaction.** The compiled `delete ... where unique_key in (select ... from temp)` and the following `insert into ... select` both sit inside the incremental materialization's single `statement("main")`, and `adapter.commit()` runs only after them, so on dbt-postgres they land or roll back together — there is no window in which the target is emptied. An adapter that auto-commits per statement is a different story; the statement count is not what decides it |
| High-cardinality upserts where most of the batch is unchanged and you want dbt to match and update row by row | `merge` | `models/marts/fct_order_items.sql` (composite `unique_key`) | native `MERGE`: Postgres 15+; Snowflake / BigQuery / Databricks natively. **There is no version fallback.** `PostgresAdapter.valid_incremental_strategies()` returns `["append", "delete+insert", "merge", "microbatch"]` on every server version and dbt emits `MERGE` unconditionally, so on Postgres 14 the run dies with `syntax error at or near "merge"`. Only the *unnamed* default strategy degrades, and not to `merge`'s semantics — `postgres__get_incremental_default_sql` picks `delete+insert` when a `unique_key` is set and `append` when it is not |
| Time-partitioned backfill of a large history, where the load must be split so a failure is retryable per period rather than for the whole model | `microbatch` | `models/marts/fct_orders_microbatch.sql` | upstream must declare `event_time`; the model needs `event_time`, `begin`, `batch_size`. **On dbt-postgres it is implemented as MERGE, so `unique_key` is mandatory** — and the failure is delayed to batch 2. Adapters with native partition replacement do not need it |
| A partition-level overwrite on a warehouse that supports it | `insert_overwrite` | *not demonstrated* | BigQuery / Spark / Databricks |

The two cues most selection questions turn on: **is any historical row ever updated?**
(no → `append`) and **is the natural unit of work a time period rather than a set of keys?**
(yes → `microbatch`).

### 1.5.1 The half of an incremental predicate a green run never checks

A watermark answers *what changed*. It does not answer *what is now in scope*, and the two come
apart the moment eligibility depends on anything but the watermark column. All three incremental
marts here had it wrong until 2026-09-06, and every run exited 0 throughout.

| Concept | Repo artifact | Measured | Status |
|---|---|---|---|
| A time-based eligibility rule defeats a `updated_at` watermark | `models/marts/fct_orders.sql`, `models/marts/fct_order_items.sql` — both cut on `created_at <= now()`, and the fixture carries orders dated into the future | 5 orders became eligible within one day; **3 carried an `updated_at` below the mart's maximum** and were selected by nothing. A full refresh at the same clock returned all five. The predicate now unions the watermark with a `not exists` probe for eligible-but-absent keys, and the missing order plus its three lines land on a plain incremental run | full |
| `not exists`, not `not in`, for the absence arm | same two models | `not in` against a subquery that can yield NULL evaluates to NULL for every row and selects nothing — a correct-looking predicate that returns an empty change set | full |
| A roll-up cannot watermark its own business date | `models/marts/fct_daily_sales.sql` | `created_at >= max(sales_day)` can never revisit an older day. Correcting order 1 (2025-01-09) left the roll-up at **314.56 while `fct_orders` summed to 423.06**, both models green and every test passing. It now carries `source_built_at`, a high-water mark over `fct_orders.dbt_updated_at`, and rebuilds every day holding a newer parent row | full |
| Keep the high-water mark in the TARGET, not in a run-time `max()` over the parent | `models/marts/fct_daily_sales.sql` | build `fct_orders` twice without building the roll-up in between and `max(fct_orders.dbt_updated_at)` sees only the second generation — the day the first one touched is lost. The stored mark advances only when this model consumes a generation | full |
| The migration cost of the new column | `on_schema_change: ignore` (required: an incremental model with a contract may only set `append_new_columns` or `fail`) | an already-built table does not grow it, so the next incremental run returns `column "source_built_at" does not exist`. `dbt run --select fct_daily_sales --full-refresh` once; a fresh clone never sees it. See [RELEASE-NOTES §13](RELEASE-NOTES-1.11.md) | full |

Strategy choice is not the only incremental config the guide names. One more, exercised here:

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `merge_exclude_columns` — restricting what a MATCHED row updates | `models/marts/fct_order_items.sql` (`merge_exclude_columns=['loaded_at']`). By default a merge overwrites every column of a matched row; this keeps the first-seen `loaded_at` instead of resetting it on every re-merge. It is written into the DDL, not passed as a warehouse flag, so the compiled merge is where you see it: `when matched then update set` names all fourteen other columns and not `loaded_at`, while `when not matched then insert` still names all fifteen — an inserted row has no previous value to preserve. `merge_update_columns` is the same lever as an allowlist; the two are mutually exclusive. **Measured, not inferred:** order 1 line 1 sat at `loaded_at = 2025-01-13 14:18:38`; setting the source line's `loaded_at` to `now()` and pushing the parent order's `updated_at` past the watermark gives `MERGE 1` with `order_updated_at` moved — so the row really was updated — and `loaded_at` still `2025-01-13 14:18:38`. One trap when reproducing: the model's predicate takes a **global** max of `order_updated_at` and the fixture is dated into the future, so `updated_at = now()` selects nothing and reports `MERGE 0`, which reads like the feature failing | `dbt run --select fct_order_items`, then `grep -A 30 'merge into' target/run/dbtae_companion/models/marts/fct_order_items.sql` | full |

### 1.6 Snapshots

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Snapshot **SQL-block form** (`{% snapshot %}` + `{{ config() }}`) | `snapshots/snp_customers_timestamp.sql`, `snapshots/snp_products_check.sql` | `dbt snapshot` | full |
| Snapshot **YAML form** (`snapshots:` block with `relation:`) | `snapshots/_snapshots.yml` — `snp_products_yaml` over `source('raw_ecom','product_catalog')`. The file header states the trade-off: a YAML snapshot takes a *relation*, not a query, so it cannot alias, derive or drop a column | `dbt snapshot`; `dbt ls --resource-type snapshot` | full |
| `strategy: timestamp` + `updated_at` | `snapshots/snp_customers_timestamp.sql` | `dbt snapshot --select snp_customers_timestamp` | full |
| `strategy: check` + `check_cols='all'` | `snapshots/snp_products_check.sql` — `all` is safe *because* the SELECT projects six business columns and leaves out `created_at` / `updated_at` / `loaded_at`. `check_cols: all` is a statement about the projection, not about the table | `dbt snapshot --select snp_products_check` | full |
| `strategy: check` + explicit `check_cols` list | `snapshots/_snapshots.yml` (`[name, sku, category_id, price_cents, is_active]`) — the YAML form cannot drop the audit columns, so `all` there would mint a new SCD2 version on every re-load that touched `loaded_at` | `dbt snapshot` | full |
| `schema:` (replaces `target_schema`) | `snapshots/*.sql`, `snapshots/_snapshots.yml`, and `dbt_project.yml` (`snapshots: +schema: snapshots`) | inspect — it routes through `generate_schema_name`, so dev lands in `dev_snapshots` | full |
| `hard_deletes: new_record` / `ignore` | `snp_products_check.sql` (`new_record` — adds a `dbt_is_deleted` column), `snp_customers_timestamp.sql` (`ignore`) | `dbt snapshot --select snp_products_check` | full |
| `dbt_valid_to_current` sentinel | `snapshots/snp_products_check.sql` (`'9999-12-31'::timestamp`), so downstream `between` predicates work without a NULL guard | `psql -c "\d dev_snapshots.snp_products_check"` | full |
| Generated columns (`dbt_valid_from`/`_to`/`dbt_scd_id`/`dbt_updated_at`) | after running snapshots | `psql -c "\d dev_snapshots.snp_customers_timestamp"` | full |
| Scripted row mutation between runs (observable SCD2 history) | `scripts/mutate-customers.sql` bumps one customer's email and `updated_at` | `psql -f scripts/mutate-customers.sql && dbt snapshot` → customer 7 gains a second row with `dbt_valid_from` / `dbt_valid_to` populated. **One-way**: the snapshot goes 200 → 201 rows and stays there | full |

### 1.7 Seeds

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Seed CSVs | `seeds/country_codes.csv` (10 rows), `seeds/product_categories.csv` (6 rows) | `dbt seed` | full |
| `column_types` | `dbt_project.yml` (`country_codes: +column_types: {country_code: varchar(2), country_name: varchar(60)}`) | `dbt seed --full-refresh` | full |
| `quote_columns` | `dbt_project.yml` (`product_categories: +quote_columns: true`) | `dbt seed` | full |
| `+schema:` override | `dbt_project.yml` (`seeds: +schema: reference`) — lands in `dev_reference` via `generate_schema_name` | `dbt seed && psql -c "\dn"` | full |

### 1.8 Using dbt packages

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `packages.yml` Hub source | `packages.yml` — `dbt-labs/dbt_utils`, `metaplane/dbt_expectations`, `dbt-labs/audit_helper`, `dbt-labs/codegen` | `dbt deps` | full |
| Exact + range version pins | `packages.yml` (range on `dbt_utils`, exact on the other three) | `dbt deps` | full |
| Git source shape | `packages.yml`, commented example | uncomment + `dbt deps` | partial (commented) |
| Local source shape | `packages.yml`, commented `local: ../shared_pkg` | uncomment + `dbt deps` | partial (commented) |
| Tarball / private source shapes | `packages.yml`, commented examples — the private shape needs git auth | — | skip |
| `package-lock.yml` | committed. Includes `godatadriven/dbt_date` as a **transitive** dependency of `metaplane/dbt_expectations`, not declared directly. That package moved namespace from `calogica`; staying on the old one raised `PackageRedirectDeprecation` until the bump | inspect | full |
| `dbt deps --lock` / `--upgrade` | no committed fixture — run them directly | `dbt deps --lock`; `dbt deps --upgrade`. Both exit 0 and leave `package-lock.yml` **byte-identical**, because every pin already resolves to the version the lockfile records. Both *write* the tracked lockfile, so run them on a copy unless you mean to change it | partial (no fixture) |
| `dbt deps --add-package` | concept only | `dbt deps --add-package dbt-labs/dbt_project_evaluator` | partial (no fixture) |
| `packages-install-path` | default `dbt_packages/` | gitignored; removed by `dbt clean` | full |
| `dbt_utils.generate_surrogate_key` | `models/staging/stg_customers.sql` | `dbt compile --select stg_customers` | full |
| `dbt_utils.star(from=…, except=[…])` | `models/staging/stg_orders.sql` | `dbt compile --select stg_orders` | full |
| `dbt_utils.expression_is_true` (package generic test) | `models/marts/_marts__models.yml`, model-level on `fct_orders` with `severity: warn` | `dbt test --select fct_orders` | full |
| `dbt_expectations.expect_column_values_to_match_regex` | `models/staging/_staging__models.yml` (`stg_customers.email`) | `dbt test --select stg_customers` | full |
| `audit_helper.compare_relations` | `analyses/compare_fct_orders_versions.sql` — compares `fct_orders` against `fct_orders_microbatch`, two genuinely different relations, and reports a real difference (the two models cut the stream at different granularities) | `dbt compile --select resource_type:analysis`, then paste `target/compiled/dbtae_companion/analyses/compare_fct_orders_versions.sql` into psql. **`--select analysis:<name>` is not valid** — see [§1.12](#112-node-selection) | full |
| `codegen.generate_source` | run-operation only | `dbt run-operation codegen.generate_source --args '{schema_name: raw_ecom}'` | full |
| Overriding a dispatched package macro | `macros/generate_surrogate_key.sql`, which defines **`default__generate_surrogate_key`**. That *name* is what makes the override win: dispatch looks for `postgres__generate_surrogate_key`, then `default__generate_surrogate_key`. A macro named `dbtae_companion__generate_surrogate_key` would never be found | `dbt compile --select stg_customers`, then inspect the compiled SQL | full |
| `dispatch:` in `dbt_project.yml` | `dbt_project.yml` (`macro_namespace: dbt_utils`, `search_order: ['dbtae_companion','dbt_utils']`) — kept as the config's canonical shape, and **labelled redundant in the file itself**: with no `dispatch:` entry, dbt already searches `[<root project>, <namespace>]`. The block is what you edit to *change* that order, not what enables an override | `dbt parse` | partial (syntax exemplar; no behavioural delta as written) |

### 1.9 Granting model access via `grants`

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `grants:` on a model (replace semantics) | `models/marts/fct_orders.sql` (`grants={'select': ['bi_reader']}`) — replaces the inherited project grant, so `fct_orders` ends up granted to **`bi_reader` only** | `psql -c "\dp dev.fct_orders"` | full |
| `+grants:` at project level | `dbt_project.yml` (`marts: +grants: {select: ['analytics_reader']}`) | same | full |
| `'+select':` merge vs `select:` replace | `models/marts/fct_order_items.sql` (`grants={'+select': ['finance_reader']}`) — merges with the inherited grant, so that relation has **two** grantees: `analytics_reader` and `finance_reader` | `psql -c "\dp dev.fct_order_items"`; verifier `.devcontainer/_check_grants.sh` | full |
| `select: []` — revoking every grantee | `models/marts/dim_pii_customers.sql` (`grants={'select': []}`). An empty list is an ordinary model-level `select:`, so replace semantics apply and the inherited folder grant is replaced with nothing. Verified: every other mart in `marts/` shows `analytics_reader`, this one shows no grantee at all. **What the empty list DOES depends on whether the relation survives the run.** This model is a `table`, dropped and recreated each build, so the new relation starts with no grantees and dbt simply issues no `grant` — there is no `revoke` in the log because there was nothing to revoke. On a relation that persists, the same empty set makes dbt issue the statement: `psql -c "grant select on dev.fct_order_items to marketing_reader"` then `dbt run --select fct_order_items` logs `revoke SELECT on "dbtae"."dev"."fct_order_items" from "marketing_reader"`. Distinct from **deleting** the config, which stops dbt managing grants on the relation at all: whatever privileges are on the relation stay, with no log line saying so. One line of YAML apart, opposite outcomes | `bash .devcontainer/_check_grants.sh` — three assertions, with `dim_customers` as the control that proves the folder default is landing at all | full |
| Pre-created Postgres roles | `db-init/01-roles.sql` (`bi_reader`, `analytics_reader`, `finance_reader`, `marketing_reader`) | created automatically on `docker compose up` | full |

### 1.10 The seven named commands

The guide names `build`, `run`, `test`, `docs`, `show`, `snapshot`, `seed`.

| Command | Verified invocation | Status |
|---|---|---|
| `dbt build` | `dbt build` → `Done. PASS=117 WARN=0 ERROR=0 SKIP=0 NO-OP=3 TOTAL=120`, exit 0 | full |
| `dbt run` | `dbt run --select fct_orders --full-refresh` | full |
| `dbt test` | `dbt test` (86 generic), `dbt test --select test_type:singular` (3), `dbt test --select test_type:unit` (3) | full |
| `dbt docs generate` / `docs serve` | `dbt docs generate && dbt docs serve --port 8080` (port mapped in the devcontainer) | full |
| `dbt show` | `dbt show --select dim_customers` and `--select stg_orders` return rows, as does `dbt show --inline "select count(*) from {{ ref('fct_orders') }}"`. `fct_daily_sales` previews empty immediately after it consumes its parent build: its strict `dbt_updated_at > max(source_built_at)` predicate then has no changed day. **A model whose `is_incremental()` branch is a strict watermark previews empty right after a build**: `dbt show --select fct_orders --limit 3` prints the header and *no data rows*, and so do `fct_order_items` and `fct_audit_events`. `dbt show` runs the *compiled* SQL; the relation exists, so `is_incremental()` renders true and the preview is the (empty) delta. The materialization is not what decides it — the author's predicate is. `fct_orders_microbatch` previews **in full**, because a microbatch model carries no `is_incremental()` guard | full |
| `dbt snapshot` | `dbt snapshot`; `dbt snapshot --select snp_customers_timestamp` | full |
| `dbt seed` | `dbt seed`; `dbt seed --full-refresh` | full |

Other commands exercised here: `dbt parse`, `dbt compile`, `dbt deps`, `dbt clean`, `dbt debug`,
`dbt ls`, `dbt retry`, `dbt clone`, `dbt source freshness`, `dbt run-operation`.

| Command | Notes | Status |
|---|---|---|
| `dbt run-operation` | `dbt run-operation grant_select --args '{schema: dev, role: bi_reader, dry_run: true}'` (`macros/grant_select.sql`) | full |
| `dbt compile --inline` | `dbt compile --inline "select * from {{ ref('stg_orders') }} limit 1"` | full |
| `dbt init` | not demonstrable inside an existing project; it creates new ones | skip |

### 1.11 Dry runs and sample mode

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `--empty` dry run (validate logic and schema without moving data) | works against the whole project | `dbt build --target ci --empty --full-refresh` → `Done. PASS=117 … TOTAL=120`, exit 0. **The trap worth seeing:** every data test passes vacuously against zero rows, so a green `--empty` build proves the SQL compiles and the schema is buildable — not that the data is right | full |
| `--sample` (run models over a time window) | `event_time` declared on `models/staging/stg_orders.sql` **and** on the `raw_ecom.orders` source | `dbt run --target ci --select stg_orders --sample='{"start": "2026-01-01", "end": "2026-03-01"}'` → 175 rows. `dbt run --sample '3 days'` is clean. Never reuse a fixed calendar window without checking `data-seed/GENERATED.md` — a window outside the fixture returns 0 rows and still exits 0 | full |
| `event_time`, all three config surfaces | inline `{{ config(event_time=...) }}` (`models/staging/stg_orders.sql`), a properties `config:` block (the `raw_ecom.orders` source in `models/sources.yml`), and `dbt_project.yml` (`staging: stg_audit_events: +event_time: occurred_at`). The three are interchangeable; only the project-file form can set the config without editing the model, or set it for a whole folder. The project-file one is not decorative — it changes compiled SQL: `dbt run --select fct_audit_events --sample '3 days'` compiles the ref as `from (select * from "dbtae"."dev"."stg_audit_events" where occurred_at >= '…' and occurred_at < '…') _dbt_et_filter_subq_stg_audit_events`. Delete the line and the same command returns every row, silently | `dbt run --select fct_audit_events --sample '3 days'` → exit 0, then read `target/compiled/dbtae_companion/models/marts/fct_audit_events.sql`. Note `--sample` is a run/build flag only: `dbt compile --sample` exits 2 with `No such option` | full |
| `--sample` fails open without `event_time` | `stg_order_items`'s description in `models/staging/_staging__models.yml` documents this at length: `raw_ecom.order_items` carries no business timestamp, so the parent is sampled and the lines are not, and the `relationships` test then reports every line as an orphan | `dbt build --sample '3 days'` → exit 1 on `relationships_stg_order_items_order_id__order_id__ref_stg_orders_`. `dbt build --sample '3 days' --exclude relationships_stg_order_items_order_id__order_id__ref_stg_orders_` → `PASS=115 … TOTAL=118`, exit 0 | full (the failure is the lesson, not a defect) |

### 1.12 Node selection

Node selection is exercised through the CLI; the guide places the commands and their selectors
in Topic 01. `state:` and `result:` selection is a Domain 07 bullet — see
[§7.1](#71-state-and-state-selection).

#### Selection methods

| Method | Verified invocation | Status |
|---|---|---|
| default (`fqn`) | `dbt ls --select fct_orders` | full |
| `tag:` | `dbt ls --select 'tag:daily,tag:critical'` → 20 | full |
| `config.materialized:` | five materializations present across 19 models | full |
| `source:` | `dbt test --select "source:*"` | full |
| `path:` / `file:` | `dbt ls --select 'models/staging/stg_*'` → 34 | full |
| `package:` | `dbt ls --select package:dbtae_companion` → 125. **`package:dbt_utils` selects 0** — a package that contributes only macros contributes no selectable nodes. The method works; the intuition is the trap | full |
| `group:` | `dbt ls --select 'group:pii'` → 4; `group:marketing` → 5. **`group:finance` → `No nodes selected!`** — it is declared in `models/_groups.yml` with an owner but has no members. Three groups declared, two populated | full |
| `access:` | `dbt ls --select 'access:private'` → 4 (one model plus its three tests). One model is `public` (`fct_orders`); 17 are `protected` by default | full |
| `test_name:` | `dbt test --select test_name:value_in_range` → 1 | full |
| `test_type:generic` / `singular` / `unit` | 86 / 3 / 3 | full |
| `resource_type:` | `dbt compile --select resource_type:analysis` ✅. Note `dbt ls --select resource_type:analysis` returns `No nodes selected!` — `dbt ls` excludes analyses from its default resource-type set and `--select` cannot add them back. Use `dbt ls --resource-type analysis` | full (with the `dbt ls` caveat) |
| `analysis:` | **not a valid method.** `dbt ls --select analysis:<name>` and `dbt compile --select analysis:<name>` both exit 2 with `'analysis' is not a valid method name` | skip (does not exist) |
| `version:` | `dbt ls --select 'version:latest'` → 1; `version:old` → 1; `version:none` → 86; `version:prerelease` → 0. Selects by semantic position, not by number | full |
| `exposure:` | see [§6.1](#61-exposures) | full |
| `state:` / `result:` / `source_status:` | see [Domain 7](#domain-7--leveraging-the-dbt-state) and [§6.2](#62-source-freshness) | full |

#### Graph operators

| Operator | Verified invocation | Status |
|---|---|---|
| `+model` / `model+` / `+model+` | `dbt ls --select +fct_orders` → 64; `dbt ls --select fct_orders+` → 27 | full |
| `N+` / `+N` depth | the same four-layer DAG (`raw → stg_* → int_* → fct_*/dim_* → exposure`) | full |
| `@model` | `dbt ls --select @fct_orders` → 106 | full |
| `,` intersection vs space union | `dbt ls --select 'tag:daily,tag:critical'` → 20 (intersection) | full |
| `*` wildcard | `dbt ls --select 'staging.stg_*'` → 34; `'*stg_*'` → 34; `'models/staging/stg_*'` → 34; `'tag:pii_*'` → 14 (tags `pii_gdpr` and `pii_adjacent`). **A bare `stg_*` selects 0** — the `fqn` method matches path-qualified names, so a bare prefix needs a path segment or a leading `*`. Note `pii` is also a *group*, which is a different method | full |
| `--exclude` | `dbt build --sample '3 days' --exclude relationships_stg_order_items_order_id__order_id__ref_stg_orders_` → exit 0; `selectors.yml`'s `nightly_core` also uses an `exclude:` clause | full |
| `--indirect-selection` (`eager` / `cautious` / `buildable` / `empty`) | measured against the shipped baseline, the same `state:modified` selector returns **8** nodes under the default `eager`, 7 under `cautious`, 7 under `buildable`, and **2** under `empty` — the six generic tests on `stg_products` come along because their parent was selected. `dbt ls --select state:modified --state ./prior-artifacts --indirect-selection empty` | full |

#### YAML selectors and global flags

| Item | Artifact | Command | Status |
|---|---|---|---|
| `selectors.yml` | three named selectors: `nightly_core` (union of two tags, excluding `group:pii`), `slim_ci` (`state:modified` with `children: true`), `critical_only` | `dbt build --selector nightly_core` → `PASS=51 … TOTAL=51`; `--selector critical_only` → 22 | full |
| `--full-refresh` | | `dbt run --select fct_orders --full-refresh` | full |
| `--vars` | | `dbt build --vars '{force_test_fail: true}'` | full |
| `--target` | | `dbt build --target ci --empty --full-refresh` | full |
| `--warn-error` | | `dbt --warn-error parse` → exit 2, versus `dbt parse` → exit 0. See [§3.5](#35-managing-dbt-behaviour-with-flags) | full |
| `--debug` | | `dbt --debug run --select stg_orders` | full |
| `--no-partial-parse` | | `dbt parse --show-all-deprecations --no-partial-parse` → 0 deprecations | full |
| `--threads` / `--fail-fast` / `--profiles-dir` / `--project-dir` | valid global flags | not individually exercised against this repo, so no claim is made about their observable effect here | partial (not exercised) |
| `.dbtignore` | `.dbtignore` lists `_scratch/` and `exercises/`. Note the file's own framing: `exercises/` already sits outside every `*-paths`, so the line is a **second guard**, not the mechanism | `dbt parse` | full |

### 1.13 Documentation artifacts — retained, no longer its own domain

Documentation was removed as an exam domain. Nothing here was deleted: `dbt docs generate` and
`dbt docs serve` are two of the seven named commands in Domain 01, and exposures are a Domain 06
bullet. Doc blocks, descriptions and `persist_docs` remain because they are cheap, correct, and
feed those two — but they are no longer a separately assessed skill.

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `dbt docs generate` / `dbt docs serve` | any project state | `dbt docs generate && dbt docs serve --port 8080` | full |
| `--no-compile` / `--empty-catalog` | flags on `docs generate` | `dbt docs generate --no-compile`; `dbt docs generate --empty-catalog` | full |
| `manifest.json` / `catalog.json` | `target/` | inspect | full |
| Model / column / source descriptions | `models/marts/_marts__models.yml`, `models/staging/_staging__models.yml`, `models/sources.yml` | docs site | full (no longer an assessed bullet) |
| Doc blocks `{% docs %}` + `{{ doc() }}` | `models/docs/glossary.md` — three blocks (`order_status`, `pii_email`, `surrogate_key_convention`), all referenced from YAML | docs site | full (no longer an assessed bullet) |
| `persist_docs: {relation: true, columns: true}` | `dbt_project.yml`, project-wide | `psql -c "\d+ dev.fct_orders"` shows the COMMENTs | full |
| `meta:` on resources + `+meta:` in project | `models/exposures.yml`, `dbt_project.yml` (`marts: +meta: {layer: gold}`) | `grep meta target/manifest.json` | full |
| `enabled: false` removes a node from the graph | `models/marts/_example_disabled.sql`. Verifier: `.devcontainer/_verify_disabled.sh` | `dbt ls --resource-type model` → 19, with the disabled node absent | full |
| Adapter DDL variance for `persist_docs` | Postgres emits `COMMENT ON`; other adapters differ | — | skip (prose only) |

---

## Domain 2 — Managing dbt models governance

### 2.1 Contracts

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `contract: {enforced: true}` + typed `columns:` | four contracted models — `dim_products`, `fct_order_items`, `fct_segment_activity`, and `dim_customer_segments` (both versions) — declared in `models/marts/_marts__models.yml` | `dbt run --select dim_products` | full |
| A contract on an *incremental* model | `models/marts/fct_order_items.sql` — and this is why it runs `on_schema_change='fail'`: dbt refuses a contract combined with `sync_all_columns` or `ignore` | `dbt run --select fct_order_items` | full |
| Contract preflight failure | `exercises/contract_drift/` | copy the case in, then `dbt run --select contract_drift` → exit 1, `This model has an enforced contract that failed` plus a mismatch table. Note **run**, not parse: `dbt parse` and `dbt compile` are clean | full |

### 2.2 Versioning and deprecation

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `versions:` + `latest_version:` | `models/marts/_marts__models.yml` (`dim_customer_segments`, v1 and v2, `latest_version: 2`) plus `dim_customer_segments_v1.sql` / `_v2.sql` | `dbt run --select dim_customer_segments`; `dbt ls --select 'version:latest'` → 1 | full |
| Per-version `columns:` override | the same block — v1 has `segment`; v2 has `spend_segment`, `recency_segment` and lifetime measures | inspect | full |
| `columns.include` / `columns.exclude` | the same block. The model-level `columns:` above `versions:` is the shared base (`customer_id`, `segment`); **v1 takes it whole with `- include: '*'`** and **v2 takes it minus one column with `- include: '*'` + `exclude: [segment]`**, because v2 replaced `segment` with `spend_segment` and `recency_segment`. Inherited columns come first and keep base order, which is what makes the resulting contract match the SQL's select order. A version with no include/exclude element behaves as if it wrote `include: '*'` | `dbt parse`, then read `target/manifest.json`: `dim_customer_segments.v1` → `['customer_id','segment']`, `.v2` → `['customer_id','spend_segment','recency_segment','orders_lifetime_count','orders_lifetime_usd','latest_order_at']` | full |
| `exclude` paired with an explicit `include` LIST — invalid, **and the error does not say why** | change v2's element to `include: [customer_id]` and keep the `exclude:`. `dbt --no-partial-parse parse` exits 2, but prints a mashumaro type failure, not the rule: `Field "columns" of type Union[IncludeExclude, UnparsedColumn] in UnparsedVersion has invalid value {'include': ['customer_id'], 'exclude': ['segment']}`. dbt 1.11.14 does raise the real message internally (`exclude can only be specified if include is one of ('all', '*')`) but it is swallowed by union resolution and never reaches the terminal | `dbt --no-partial-parse parse` → exit 2 | full |
| Dropping the `exclude` (counter-example) | delete `exclude: [segment]` from v2 and `dbt run --select dim_customer_segments_v2` → exit 1, contract preflight table `\| segment \| \| TEXT \| missing in definition \|`. The inherited column is not silently ignored; it becomes part of the contract | `dbt run --select dim_customer_segments_v2` | full |
| `defined_in:` | the same block (`defined_in: dim_customer_segments_v1`) | inspect | full |
| `deprecation_date:` | `models/marts/_marts__models.yml` — v1 carries a **future** date (`2027-12-31`), deliberately. A *past* date makes dbt warn on every single run, plus once per downstream ref, which drowns out real warnings. A downstream `ref()` at a version that has any `deprecation_date` still produces an advisory — see [§3.5](#35-managing-dbt-behaviour-with-flags) | `dbt parse` → one `[WARNING]` naming `dim_customer_segments.v1` | full |
| `ref('model', v=N)` consumer | `models/marts/fct_segment_activity.sql` (`v=1`); `models/exposures.yml` (`v=2`) | `dbt ls --select +fct_segment_activity` | full |
| Selecting a bad version (counter-example) | `exercises/ref_bad_version/` | copy the case in, then `dbt parse` → exit 2, `depends on a node named 'dim_customer_segments' with version '99'` | full |

### 2.3 Access, groups, and constraints in YAML

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `groups:` block with `owner:` | `models/_groups.yml` — `pii`, `marketing`, `finance`. **`finance` has no members**: declared with an owner, but nothing is assigned to it | `dbt ls --select 'group:pii'` → 4; `dbt ls --select 'group:finance'` → `No nodes selected!` | full (with the empty-group caveat) |
| `access: private` | `models/marts/dim_pii_customers.sql` (group `pii`) | `dbt ls --select 'access:private'` → 4 | full |
| `access: protected` (default) | 17 models | — | full |
| `access: public` | `models/marts/fct_orders.sql` | — | full |
| Cross-group `ref()` into a private model | `exercises/access_violation/` | copy the case in, then `dbt parse` → exit 2, `Parsing Error … not allowed because the referenced node is private to the 'pii' group`. dbt 1.11 prints no `DbtReferenceError` label | full |
| `access: public` + `ephemeral` disallowed | `exercises/public_ephemeral/` | copy in, `dbt parse` → exit 2, `with 'ephemeral' materialization has an invalid value (public) for the access field` | full |
| Constraint — `not_null` | `dim_products` on `product_id`, `sku`, `product_name`, `price_cents`, `price_usd` | `psql -c "\d+ dev.dim_products"` | full |
| Constraint — `check` | `dim_products` column **`price_cents`**, `expression: "price_cents >= 0"`. Warehouse DDL: `CHECK ((price_cents >= 0))`. (`price_usd` carries only `not_null`.) | insert a negative `price_cents` → Postgres rejects it | full |
| Constraint — `primary_key` | `dim_products`, model-level `constraints: [{type: primary_key, columns: [product_id]}]` | `psql -c "\d+ dev.dim_products"` | full |
| Constraint — `unique` | `dim_products.sku`; also `dim_customer_segments` v1 and v2 on `customer_id` | `psql -c "\d+ dev.dim_products"` | full |
| Constraint — `foreign_key` with `to:` / `to_columns:` | `models/marts/_marts__models.yml`, on **`fct_segment_activity.customer_id` → `ref('dim_customer_segments', v=1)`**. The `to:` form takes a `ref()` (a `source()` works too) instead of a hardcoded relation name, so dbt resolves the target per target *and* the reference becomes a real DAG edge. Postgres enforces it: `FOREIGN KEY (customer_id) REFERENCES dev.dim_customer_segments_v1(customer_id)` | `dbt build --select fct_segment_activity`, then `psql -c "\d dev.fct_segment_activity"`. **Rebuild the declaring model first**: the constraint is created with the table, and anything that rebuilds `dim_customer_segments_v1` on its own drops it again — see the next row | full (with the rebuild-order caveat below) |
| Why the FK is **not** on `fct_order_items` | dbt-postgres drops a table model with `drop table … cascade`, which drops every foreign key pointing at it. A constraint therefore survives only if the model declaring it is rebuilt after its target, **in the same invocation** — true for `fct_segment_activity` inside a full `dbt build`, false for an incremental fact table, which is rebuilt only on `--full-refresh`. So the equivalent `fct_order_items → dim_products` invariant is expressed as a `relationships` **test**, which is durable. The reasoning is written into `models/marts/_marts__models.yml` | `dbt test --select fct_order_items` | full |
| That the FK is **transient**, not just conditional | the same pair. `dbt run --select dim_customer_segments_v1` alone → exit 0, and `select count(*) from pg_constraint where connamespace='dev'::regnamespace and contype='f'` drops from 1 to **0**: the target was replaced, `cascade` took the constraint with it, and nothing rebuilt the model that declares it. `dbt build --select fct_segment_activity` puts it back. The §3.4 failure-injection drill SKIPs `fct_segment_activity`, so it leaves `dev` with no foreign key at all — a declared constraint is a property of the *last build*, not of the project | `dbt run --select dim_customer_segments_v1`, then re-run the `pg_constraint` count | full |
| The `check`-constraint `data_type` trap | `exercises/constraint_missing_data_type/` — a contracted model whose `check` sits on a column with no `data_type` | copy the case in, then `dbt run --select constraint_missing_data_type` → exit 1, `Contracted models require data_type to be defined for each column`. **Run, not parse**: `dbt parse` and `dbt compile` both exit 0 | full |
| Constraint — `custom` (the sixth type, and the escape hatch) | `dim_products.price_usd`, `expression: "constraint dim_products_price_usd_nonneg check (price_usd >= 0)"`. dbt renders the expression **verbatim** into the column's DDL slot and neither parses nor validates it — that is how a Snowflake masking policy or a BigQuery policy tag reaches a contracted column, and it is why a typo here surfaces as a warehouse syntax error at run time rather than a dbt parse error. On Postgres the same slot takes a NAMED check, which the typed `check` constraint cannot produce. Both are then visible side by side, and the contrast is the lesson: `"dim_products__dbt_tmp_price_cents_check"` (Postgres autonamed it after the `__dbt_tmp` staging table it was created on, and the name did not follow the rename into place; Postgres appends a digit to that name when it is already taken, so it is not stable either) next to `"dim_products_price_usd_nonneg"` | `dbt run --select dim_products`, then `psql -c "\d+ dev.dim_products"` | full |
| All six constraint types, across the project | `not_null`, `unique`, `primary_key`, `check` and `custom` on `dim_products`; `foreign_key` on `fct_segment_activity` | the two commands above | full |
| Constraints are **inert without a contract**, and silently so | `fct_daily_sales.revenue_usd` declares a `data_type` and a `not_null` constraint, and the model has **no `contract:` block**. dbt parses the block, carries it in the manifest (`revenue_usd.constraints` → `[{'type': 'not_null', …}]`), and emits no DDL, no warning and no log line — it does not even validate the constraint, because `_validate_constraint_prerequisites` runs only when `contract.enforced is True`. The evidence is an absence, so check the warehouse rather than the run: a reviewer reading the YAML would say the column cannot be null | `dbt build --select fct_daily_sales` → exit 0, `WARN=0`; then `psql -c "\d dev.fct_daily_sales"` → `revenue_usd`'s Nullable column is **blank**. Compare `\d dev.dim_products`, where the same `not_null` under an enforced contract does print `not null` | full |
| Adapter variation in constraint enforcement | Postgres enforces `not_null`, `check`, `unique`, `primary_key` and `foreign_key` for real. Many cloud warehouses treat PK / FK / unique as metadata-only. This repo is therefore the *most* honest place to watch enforcement and the *least* representative of cloud production | — | skip (prose only) |

---

## Domain 3 — Debugging data modeling errors

### 3.1–3.3 Reading errors, compiled code, and YAML failures

The `exercises/` tree holds **twenty-two** deliberately-broken cases, one per directory, each
failing for exactly one reason at exactly one layer, each with a README quoting the error dbt
actually emits. `.devcontainer/_test_exercises.sh` runs every case and asserts three things —
the exit code, the **failing layer**, and the message — so the catalogue cannot drift from
reality. The layer assertion is the one that catches an upgrade moving an error between parse
and compile, which a message regex alone would pass straight over.

**Six of the twenty-two emit no error worth matching**, and those are asserted against the
artifact instead: `yaml_unknown_key` and `test_config_not_nested` against the config the
manifest actually records, `hardcoded_relation`, `depends_on_comment` and `conditional_ref`
against the `depends_on.nodes` dbt actually built, and `merge_no_unique_key` against its
compiled `MERGE` SQL. A console regex on any of them would record a PASS for silence — which is
the failure mode the whole tree exists to teach.

The trigger flow is the same for all of them: copy the case's files into `models/_tmp_broken/`
(plus `macros/_tmp_broken/` for `dispatch_miss`), run the trigger command, delete the directory.
`exercises/` sits outside every `*-paths` entry in `dbt_project.yml`, and that is what keeps the
project green with twenty-two broken files in the repo; the `.dbtignore` line is a second guard.
Renaming a file inside `exercises/` does **not** arm it, and editing `.dbtignore` does not either
— the file has to move.

| Case | Trigger | Exit | Layer | The error, in one line | Status |
|---|---|---|---|---|---|
| `yaml_indent/` | `dbt parse` | 2 | parse (YAML load) | `did not find expected '-' indicator` | full |
| `yaml_wrong_type/` | `dbt parse` | 2 | parse | `at path ['materialized']: True is not of type 'string'` | full |
| `yaml_unknown_key/` | `dbt parse` | **0** | — | **nothing.** An unknown property is accepted silently; the key never reaches the manifest. The null result *is* the lesson | full |
| `test_config_not_nested/` | `dbt parse`, then the same parse under `--warn-error-options` | **0**, then **2** | — | `severity:` written beside the test name instead of under `config:`. `PropertyMovedToConfigDeprecation`, and the config **still applies**; promote that one deprecation and the same file is a `Compilation Error`, exit 2. Misspell the key instead and it becomes a test *argument*: `macro 'dbt_macro__test_not_null' takes no keyword argument 'serverity'`, exit 2 | full |
| `jinja_unbalanced/` | `dbt parse` | 2 | parse (Jinja) | `Unexpected end of template` | full |
| `ref_typo/` | `dbt parse` | 2 | parse | `depends on a node named 'stg_orderz' which was not found` | full |
| `ref_disabled/` | `dbt parse` | 2 | parse | `depends on a node named 'disabled_target' which is disabled` | full |
| `ref_bad_version/` | `dbt parse` | 2 | parse | `depends on a node named 'dim_customer_segments' with version '99'` | full |
| `access_violation/` | `dbt parse` | 2 | parse | `not allowed because the referenced node is private to the 'pii' group` | full |
| `public_ephemeral/` | `dbt parse` | 2 | parse | `with 'ephemeral' materialization has an invalid value (public) for the access field` | full |
| `macro_arity/` | `dbt parse` | 2 | parse | `takes no keyword argument 'precision_level'` | full |
| `dispatch_miss/` | `dbt parse` | 2 | parse | `In dispatch: No macro named 'i_am_not_implemented' found` | full |
| `cyclic/` | `dbt compile` | 2 | compile (graph link) | `Found a cycle: model.dbtae_companion.A --> model.dbtae_companion.B` — dbt does not print the closing leg | full |
| `macro_undefined/` | `dbt compile --select macro_undefined` | 2 | compile | `'generate_surrogate_key' is undefined` | full |
| `contract_drift/` | `dbt run --select contract_drift` | 1 | run | `This model has an enforced contract that failed` | full |
| `constraint_missing_data_type/` | `dbt run --select constraint_missing_data_type` | 1 | run | `Contracted models require data_type to be defined for each column` | full |
| `source_misresolved/` | `dbt run --select stg_orders_misresolved` | 1 | run | `relation "ecom_landing.orders" does not exist` | full |
| `unquoted_macro_arg/` | `dbt run --select unquoted_macro_arg` | 1 | run | `syntax error at or near "as"`. Parse and compile are both clean; the compiled file reads `round(cast( as numeric) / 100.0, 2)`, because an unquoted argument is an undefined Jinja *variable* and renders as the empty string | full |
| `hardcoded_relation/` | `dbt run --select orders_hardcoded` | 1 | run | `relation "dev.hc_upstream" does not exist` — the symptom. The diagnosis is `depends_on.nodes == []`, which is true whether or not the run happened to pass | full |
| `depends_on_comment/` | `dbt parse` | **0** | — | **nothing.** `-- depends_on: {{ ref('x') }}` registers the edge; `{# depends_on: {{ ref('x') }} #}` does not | full |
| `conditional_ref/` | `dbt parse`, twice | **0** | — | **nothing.** The same file parses to parent `stg_orders`, or to `stg_products` under `--vars '{use_products: true}'` | full |

The ordering is the drill: triage is a binary search over layers, and the **Layer** column above
is the answer key — a clean `dbt parse` clears every case marked `parse`, a clean `dbt compile`
clears the two marked `compile`, and what is left is warehouse-shaped. Five cases clear every
layer, because they never fail; that is their lesson, and for those the manifest is the only
artifact that answers the question. Exit **2** is dbt failing the command;
exit **1** is the command running with a failed node inside it. `exercises/README.md` walks the
same drill case by case.

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `target/compiled/` inspection | any built model | `cat target/compiled/dbtae_companion/models/marts/fct_orders.sql` | full |
| `target/run/` inspection (the DDL wrapper) | any `table` / `incremental` model | `cat target/run/dbtae_companion/models/marts/fct_orders.sql` | full |
| Narrow compile | any model | `dbt compile --select fct_orders` | full |
| Ad-hoc compile | no fixture needed | `dbt compile --inline "select * from {{ ref('stg_orders') }} limit 1"` | full |
| Ephemeral inlining | `int_order_items_enriched` | `dbt compile --select fct_order_items`, then read the CTE | full |
| `dbt debug` | working profile | `dbt debug` | full |
| Verbose logs | any command | `dbt --debug run --select stg_orders` | full |
| `logs/dbt.log` | default path | inspect after any run | full |

### 3.4 Building and testing a fix before merge

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Failure injection and downstream skip | the `force_test_fail` var gates a `dbt_utils.expression_is_true` test on `fct_orders` (`models/marts/_marts__models.yml`) | `dbt build --vars '{force_test_fail: true}'` → exit 1, `Done. PASS=109 WARN=0 ERROR=1 SKIP=10 NO-OP=1 TOTAL=121` | full |
| Slim CI (`state:modified+` with `--defer`) | `scripts/save-baseline.sh`, `scripts/slim-ci.sh`, `selectors.yml` (`slim_ci`) | see [§7.1](#71-state-and-state-selection) | full |
| Recovery after a failure | `dbt retry` | see [§7.2](#72-dbt-retry) | full |

### 3.5 Managing dbt behaviour with flags

There are two surfaces for setting dbt behaviour — a flag on the command line, and the `flags:`
block in `dbt_project.yml` — and the block itself does three different jobs depending on what you
put in it, one per phase of a flag's life: **Introduced** (gated, old behaviour still the default,
you may opt in early), **Mature** (the default flips, the old behaviour stays reachable by setting
the flag `false`), **Removed** (the old code path is deleted and neither value is settable). The
four live entries in the block are Mature; the three commented ones below them are Introduced. The block as shipped here is a deliberate no-op: every flag is set to the value 1.11
already defaults to. That is not the same as saying it does nothing, and the difference is worth
running yourself.

| Surface | Where it lives | What it does | In this repo | Status |
|---|---|---|---|---|
| **CLI global flag** | on the command, before the subcommand | changes one invocation | `dbt --warn-error parse` → exit 2; `dbt --debug run --select stg_orders`; `dbt parse --show-all-deprecations --no-partial-parse` | full |
| **Project `flags:` block** | `dbt_project.yml` | sets a default for every run of this project | four flags are set, all four to the 1.11 default. Delete the whole block and nothing changes — `dbt parse` exit 0, project hooks still run. The block records the upgrade decision, which is what an upgrade should leave behind | full (as shipped: a deliberate no-op) |
| **Opting *out* of a matured flag** | the same block, with a flag set to `false` | reverts one behaviour to its pre-maturity form | **two of the four bite immediately.** `require_generic_test_arguments_property: false` → `dbt parse --no-partial-parse` exit **2**, `Compilation Error … macro 'dbt_macro__test_relationships' takes no keyword argument 'arguments'`, plus `ArgumentsPropertyInGenericTestDeprecation: 1 occurrence` — the `arguments:` form this project's YAML uses stops being understood. `source_freshness_run_project_hooks: false` → `dbt source freshness` prints `Finished running 5 sources` instead of `Finished running 2 project hooks, 5 sources`. The other two flip cleanly (parse exit 0, no delta) | full |
| **A behaviour-change flag that is still *immature* at 1.11** — the INTRODUCED phase | the same block | lets a project opt into a future default early | `dbt_project.yml` carries three **commented** entries below the four live ones: `skip_nodes_if_on_run_start_fails`, `state_modified_compare_more_unrendered_values`, `validate_macro_args`. All three default to `false` at 1.11 and are scheduled to flip at 1.12, so uncommenting one moves this project to the 1.12 behaviour before the upgrade does. **All three names are read by 1.11.14** — uncomment them and `dbt --no-partial-parse parse` exits 0 with no new warning — while a made-up name in the same block is **silently ignored**, which is how a typo here becomes a flag that did nothing. They stay commented because each has a real runtime effect and this repo's published build line is measured with all three at their 1.11 default | uncomment one, then `dbt --no-partial-parse parse` | partial (the surface runs; the shipped state is deliberately inert) |

**The `--warn-error` gate, precisely.** `models/marts/fct_segment_activity.sql` refs
`dim_customer_segments` at `v=1`, and that version carries a `deprecation_date`. dbt therefore
emits an *upcoming-deprecation advisory* at compile time on every run — because a consumer refs
a version that has a deprecation date at all, **not** because that date has passed. The date is
`2027-12-31`, in the future.

```
$ dbt parse
[WARNING]: While compiling 'fct_segment_activity': Found a reference to dim_customer_segments.v1,
which is slated for deprecation on '2027-12-31T00:00:00+00:00'. …
                                                              exit 0

$ dbt --warn-error parse
Compilation Error
  [WARNING]: While compiling 'fct_segment_activity': …
                                                              exit 2
```

`--warn-error` escalates warnings globally. That is a different lever from a test's own
`error_if` threshold, which escalates one test — see [§5.3](#53-placing-test-steps-in-the-workflow).

---

## Domain 4 — Troubleshooting and optimizing dbt pipelines

### 4.1 DAG failure points

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| A failing test skips its downstream | `force_test_fail` var + `models/marts/_marts__models.yml` | `dbt build --vars '{force_test_fail: true}'` → exit 1, `PASS=109 ERROR=1 SKIP=10 NO-OP=1 TOTAL=121` | full |
| Finding what failed, and what it took down | `run_results.json` from that build | `dbt build --select result:fail+ --state ./target --vars '{force_test_fail: true}'` → exit 1, `TOTAL=3`. Both extra arguments are load-bearing — see [§7.1](#71-state-and-state-selection) | full |
| Re-running only the failures | `dbt retry` | see [§7.2](#72-dbt-retry) | full |
| A topological-sort failure | `exercises/cyclic/` | copy the case in, then `dbt compile` | full |
| Stopping at the first failure | `--fail-fast` is a valid global flag | not exercised against this repo | partial (not exercised) |

### 4.2 `dbt clone`

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `dbt clone` against a saved state | `scripts/clone-demo.sh` (against `prior-artifacts/`). Verifier: `.devcontainer/_clone_test.sh` | `dbt clone --target ci --state prior-artifacts --select fct_orders` → `Done. PASS=1 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=1`, exit 0. `clone-demo.sh` selects **two** nodes (`fct_orders fct_order_items`) and so reports `TOTAL=2` | full, with the Postgres semantics below |
| Clone semantics on Postgres | the command runs and the cloned relations are queryable, but dbt-postgres creates **pointer views** into the source schema, not zero-copy clones | `psql -c "\d+ ci.fct_orders"` | partial (pointer-view, not zero-copy) |
| Zero-copy clone semantics (divergent writes to a clone) | not possible on dbt-postgres — a Snowflake / Databricks primitive | — | skip (adapter-blocked) |
| clone versus defer | `scripts/clone-demo.sh` beside `scripts/slim-ci.sh`: clone materialises pointers in the target schema, defer resolves `ref()` to the *other* schema without creating anything | run both against an empty `ci` | full |

Both demos require an **empty `ci` schema**. Drop it first:

```bash
psql -c 'drop schema if exists ci cascade;'
psql -c 'drop schema if exists ci_snapshots cascade;'
psql -c 'drop schema if exists ci_reference cascade;'
psql -c 'drop schema if exists ci_dbt_test__audit cascade;'
```

One sharp edge, recorded rather than papered over. Cleanup after a clone cannot be a plain
`drop table if exists`: the previous run left `ci.fct_orders` as a **view**, and `DROP TABLE` on a
view raises `"fct_orders" is not a table` rather than skipping — psql then aborts the rest of the
batch. `.devcontainer/_clone_test.sh` therefore dispatches on `pg_class.relkind` in a `DO` block,
which is what makes it safe to run any number of times. `scripts/clone-demo.sh` passes
`--full-refresh` for the same family of reason: without it, a `ci.fct_order_items` table left by
`scripts/slim-ci.sh` is not replaced, and the demo reports success while the reader is looking at
a table.

---

## Domain 5 — Implementing dbt tests

### 5.1 Test types across models and sources

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Generic: `unique` | 21 call sites, e.g. `stg_customers.customer_id` | `dbt test --select stg_customers` | full |
| Generic: `not_null` | 49 call sites | same | full |
| Generic: `accepted_values` | `stg_orders.status`, `fct_orders.status`, `raw_ecom.orders.status` | same | full |
| Generic: `relationships` → `ref()` | `models/marts/_marts__models.yml`: `fct_order_items.product_id → ref('dim_products')` and `fct_orders.customer_id → ref('dim_customers')`; `models/staging/_staging__models.yml`: `stg_orders.customer_id → ref('stg_customers')` | `dbt test --select fct_order_items` | full |
| Generic: `relationships` → `source()` | `models/sources.yml`: `orders.customer_id → source('raw_ecom','customers')`, `order_items.order_id → source('raw_ecom','orders')`, `order_items.product_id → source('raw_ecom','product_catalog')` | `dbt test --select "source:*"` | full |
| Generic tests on **sources** | `models/sources.yml` — `unique`, `not_null`, `accepted_values`, `relationships` | `dbt test --select "source:*"` | full |
| Singular test | `tests/assert_fct_orders_amount_matches_items.sql` (cross-model reconciliation) | `dbt test --select test_type:singular` → 3 | full |
| Singular test with `{{ config() }}` | `tests/assert_no_future_orders.sql` | same | full |
| Custom generic test with arguments | `tests/generic/test_value_in_range.sql` (`min_value`, `max_value`), invoked on `fct_orders.order_total_usd` | `dbt test --select test_name:value_in_range` → 1 | full |
| Package-supplied generic tests | `dbt_utils.expression_is_true` (`models/marts/_marts__models.yml`), `dbt_expectations.expect_column_values_to_match_regex` (`models/staging/_staging__models.yml`) | `dbt test --select stg_customers` | full |
| The `arguments:` nesting | every generic-test call site here uses the current `arguments:` form rather than the flat form | `dbt parse --show-all-deprecations` → 0 deprecations | full |
| Test configs must nest under `config:` | `exercises/test_config_not_nested/` — `severity: warn` written as a bare sibling of the test name. Every shipped call site does it correctly, so the counter-example has to live outside the project | copy the case in, `dbt parse` → exit 0 with `PropertyMovedToConfigDeprecation`, **and the config still applies** (`dbt ls --output-keys config` shows `severity: warn`). `dbt parse --warn-error-options '{"error": ["PropertyMovedToConfigDeprecation"]}'` → exit 2, `Invalid generic test configuration given in …`. A *misspelled* key is not a config at all — it is handed to the test macro as a keyword argument and fails at parse | full |
| Unit tests — fixture-file form | `models/marts/_marts__models.yml` `unit_tests:` → `test_fct_orders_usd_conversion`, whose three `given:` inputs and its `expect:` all name CSVs under `tests/fixtures/` | `dbt test --select test_type:unit` → `Done. PASS=5 … TOTAL=5` (3 unit tests + 2 project hooks) | full |
| Unit tests — inline `rows:` form | the same block → `test_fct_orders_no_rate_match_defaults_to_one`. Both shapes sit side by side on purpose. Note the empty rate input: a header row with no data rows is how you mock "this relation is empty" | same | full |
| Unit-testing an incremental model | the two `fct_orders` tests set `overrides: {macros: {is_incremental: false}}` — the non-obvious part, since it pins which branch of the model compiles | same | full |
| `overrides.macros` reaches a macro the model never names | `models/staging/_staging__models.yml` `unit_tests:` → `test_stg_customers_override_reaches_nested_macro`. stg_customers names only `dbt_utils.generate_surrogate_key`; that dispatches to this project's `default__generate_surrogate_key`, which calls `dbt.type_string()`. The test overrides `dbt.type_string` — two calls down — and the truncated cast changes `customer_pk` from md5('42') to md5('4') | `dbt test --select test_stg_customers_override_reaches_nested_macro` → PASS. Delete the two `overrides:` lines and it reports the untouched hash instead | full |
| The limit of `overrides.macros`: it does not intercept `adapter.dispatch` | recorded in the same test's `description:`, verified 2026-09-03 but **not shipped as a fixture** — a unit test on `fct_daily_sales` overriding `postgres__date_trunc_day` leaves the real macro running, while overriding `date_trunc_day`, the name the model writes, takes effect | — | skip |
| A user-authored generic test that shadows a built-in | `tests/generic/not_null.sql` — a root-project `not_null` block wins over dbt's built-in for every call site above, with no YAML edit and no warning. It delegates to `dbt.test_not_null`, so the SQL, node count and build line are unchanged; the shadow is proved by the marker comment it injects | `dbt build`, then `grep -rl dbtae_companion__not_null_override target/compiled \| wc -l` → the `not_null` call-site count above | full |
| `overrides` for `vars` / `env_vars`; `format: dict` / `format: sql` | not used here — only `format: csv` and `overrides.macros` appear | — | partial |

### 5.2 Testing assumptions about models and sources

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Source-level assumptions | `models/sources.yml` | `dbt test --select "source:*"` | full |
| Model-level assumptions | `models/staging/_staging__models.yml`, `models/marts/_marts__models.yml` | `dbt test` | full |
| Cross-model assumption | `tests/assert_fct_orders_amount_matches_items.sql` | `dbt test --select test_type:singular` | full |
| Placing an assumption at the layer that owns the rule | `tests/assert_no_future_orders.sql` sits on `fct_orders`, not on `stg_orders`, because the mart is where the future-order rule is applied. Pointed at staging it would either fail forever or quietly pass once the fixture aged out — a test that decays into a false green. The test file explains this | `dbt test --select assert_no_future_orders` | full |
| Tests run in DAG order | `dbt build` interleaves each test with the model it depends on | `dbt build` | full |

### 5.3 Placing test steps in the workflow

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Project-wide test defaults | `dbt_project.yml` (`data_tests: +severity: error, +store_failures: false`) — these match the built-in defaults; the block is present to show where project-wide test config lives | `dbt parse` | full |
| Test config precedence (inline beats project beats built-in) | `tests/assert_no_future_orders.sql` sets `severity`, `store_failures`, `store_failures_as`, `limit` and `tags` inline | inspect `target/manifest.json` | full |
| `severity` | `tests/assert_no_future_orders.sql` (`error`); the `accepted_values` test on `fct_orders.status` and `dbt_utils.expression_is_true` both use `severity: warn` in a YAML `config:` | `dbt test` | full |
| `warn_if` / `error_if` thresholds | `tests/assert_large_orders_within_review_tolerance.sql` (`severity='error'`, `warn_if='>= 8'`, `error_if='>= 30'`). All three outcomes from one knob: `dbt test --select assert_large_orders_within_review_tolerance` → PASS; `… --vars '{large_order_review_usd: 500}'` → WARN; `… --vars '{large_order_review_usd: 150}'` → FAIL. The file also records the trap: dbt consults `should_error` only when `severity` is `error`, so setting `severity='warn'` makes `error_if` unreachable | as above | full |
| `fail_calc` — the default, and the zero-row trap | default `count(*)` is not asserted, it is read off the wrapper dbt writes for every other test: `head -6 target/run/dbtae_companion/tests/assert_no_future_orders.sql`. `tests/assert_fct_orders_amount_matches_items.sql` overrides it to sum the discrepancy in cents, and ships both the wrapped and the unwrapped form behind a var | `dbt test --select assert_fct_orders_amount_matches_items` → PASS, exit 0 (`coalesce(sum(…), 0)`); `… --vars '{unsafe_fail_calc: true}'` → exit 1 with `None is not of type 'integer'` — a bare `sum()` over the zero rows a healthy dataset returns breaks the harness before any threshold is read | full |
| `store_failures: true` + `store_failures_as: table` | `tests/assert_no_future_orders.sql` | after a run: `psql -c "select * from dev_dbt_test__audit.assert_no_future_orders"`. The audit schema is `<target schema>_dbt_test__audit`, and `generate_schema_name` makes that **`dev_dbt_test__audit`** on the dev target (`ci_dbt_test__audit` under `--target ci`) | full |
| `limit:` | `tests/assert_no_future_orders.sql` (`limit=500`) — it is on the **singular** test, capping how many failing rows are stored | inspect | full |
| `where:` | `models/marts/_marts__models.yml` — `not_null` on `fct_orders.updated_at` with `where: "created_at >= current_date - interval '90 days'"`, the pattern for keeping an expensive assertion cheap on a growing fact table | `dbt test --select fct_orders` | full |
| `enabled:` gating a test on a var | `models/marts/_marts__models.yml` (`enabled: "{{ var('force_test_fail', false) }}"`) | `dbt build --vars '{force_test_fail: true}'` | full |
| `tags:` on tests | both `tests/assert_no_future_orders.sql` and `tests/assert_large_orders_within_review_tolerance.sql` carry `tags=['critical']`; `selectors.yml`'s `critical_only` picks them up | `dbt build --selector critical_only` → 22 | full |
| Test failure propagates as SKIP downstream | see [§4.1](#41-dag-failure-points) | `dbt build --vars '{force_test_fail: true}'` | full |

---

## Domain 6 — Implementing and maintaining external dependencies

*Formerly Topic 7. Two bullets: exposures, and source freshness.*

### 6.1 Exposures

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Exposures with all fields | `models/exposures.yml` — three exposures across three `type:` values (`dashboard`, `ml`, **`analysis`**), three `maturity:` levels, an `owner:` on each, a `url:` on two, and multi-node `depends_on:` including a versioned `ref('dim_customer_segments', v=2)` | `dbt ls --resource-type exposure` → 3 | full |
| `depends_on:` takes `source()` as well as `ref()` | `models/exposures.yml` (`finance_reconciliation_notebook` carries `source('raw_ecom', 'orders')` beside two `ref()`s) | `dbt ls --select '+exposure:finance_reconciliation_notebook' --resource-type source`; the direct edge is in `manifest.json` → `exposures[…].sources == [['raw_ecom', 'orders']]` | full |
| … and `metric()` | — | the parser accepts the third call type but there is no metric to point at: `metric('total_revenue')` yields `Compilation Error … depends on a metric named 'total_revenue' which was not found`. MetricFlow is out of scope, so that error message *is* the demonstration | partial |
| Exposures have no descendants | `manifest.json` → `child_map['exposure.…'] == []` | `dbt ls --select 'exposure:executive_kpi_dashboard'` → 1; `…+` → 1 (the trailing `+` is a no-op); `+…` → 69 | full |
| An `exposures:` block in `dbt_project.yml` | not shipped — add `exposures: {dbtae_companion: {+tags: [x], +meta: {…}, +enabled: false}}` | measured 2026-09-02: all three configs bind. `+enabled: false` → `dbt ls --resource-type exposure` prints `No nodes selected!`; `+tags`/`+meta` land on the two exposures that declare no `config:` of their own and lose to the one that does. The reference page's `enabled`-only carve-out is refuted | full (by edit) |
| Top-level `tags:` / `meta:` (the pre-1.10 shape) | not shipped | measured 2026-09-02: parses and is hoisted — `manifest.json` shows `config: {tags: […], meta: {…}}`. **No** `PropertyMovedToConfigDeprecation` on Postgres; that warning needs bigquery / databricks / redshift / snowflake | partial — binding shown, warning adapter-blocked |
| `type` / `maturity` enums, required properties | not shipped as fixtures | a one-word edit prints the whole enum: `'notebook_xyz' is not one of ['dashboard', 'notebook', 'analysis', 'ml', 'application']`. Deleting `type:` → `'type' is a required property`; deleting `owner:` → `'owner' is a required property`. An **unknown `owner` sub-field (`slack:`) parses clean on Postgres** — that rejection is adapter-gated too | full (by edit), except the owner-sub-field rejection |
| Exposure `config:` with `tags` / `meta` | `models/exposures.yml` (`executive_kpi_dashboard`) | `grep meta target/manifest.json` | full |
| `exposure:` selector | | `dbt ls --select '+exposure:executive_kpi_dashboard'` → 69; `dbt build --select +exposure:executive_kpi_dashboard` | full |
| Exposures are `NO-OP` in a build | the three exposures are the `NO-OP=3` in the summary line — dbt tracks them and renders them in the docs site, it does not execute them | `dbt build` | full |

### 6.2 Source freshness

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `config.loaded_at_field` + `config.freshness` at source level | `models/sources.yml` (`raw_ecom` 12h/24h; `raw_ref` 3d/7d) | `dbt source freshness` → 5 PASS, exit 0 | full |
| Table-level freshness override | `models/sources.yml` (`orders` tightens to 6h/12h) | `dbt source freshness --select source:raw_ecom.orders` | full |
| `config: {freshness: null}` opt-out | `models/sources.yml` (`audit_events`) | `dbt source freshness` — 5 of the 6 source tables are checked; `audit_events` is skipped | full |
| `freshness.filter` (1.10+) | `models/sources.yml` (`raw_ref.currency_rates`, `currency_code in ('USD','EUR','AUD')`) | `dbt source freshness` → `target/sources.json` records `"filter": "currency_code in ('USD', 'EUR', 'AUD')"` **and** keeps the source-level 3d/7d — a table-level freshness block **merges** with the source-level one. `max_loaded_at` moves off the GBP row (`…05:46:24`) to the USD row (`…03:09:42`) | full |
| `loaded_at_query` (1.10+) | `models/sources.yml` (`raw_ecom.product_catalog`) | the full alternative to `loaded_at_field`, overriding it for that table. On this fixture it returns the same instant, so the proof is negative: delete the source-level `loaded_at_field` and every other table errors `The configured adapter does not support metadata-based freshness`, while this one still PASSes | full |
| Metadata-based freshness (no `loaded_at_field`) | — | Postgres has no metadata route: `dbt source freshness` → `ERROR`, exit 1, `The configured adapter does not support metadata-based freshness. A loaded_at_field must be specified for source '…'`. The *positive* case needs Snowflake or BigQuery (`dbt-bigquery` 1.7.3+); the reference lists Redshift too, and qualifies **Databricks as dbt Fusion engine support**, not Core | skip — adapter-blocked |
| `warn_after` / `error_after` shape | `models/sources.yml` | measured 2026-09-02: a **count-only** threshold is silently discarded, not rejected — `sources.json` records `"warn_after": {"count": null, "period": null}` with no error and no warning. With **neither** threshold the table is not selected at all: `Nothing to do.` `period: minute` is accepted | full (by edit) |
| Top-level `freshness:` / `loaded_at_field:` (pre-1.10 shape) | not shipped | measured 2026-09-02: binds and PASSes on Postgres with **no** `PropertyMovedToConfigDeprecation`; the warning needs bigquery / databricks / redshift / snowflake | partial — binding shown, warning adapter-blocked |
| `dbt build` never runs freshness | — | with every source forced stale (`psql -f scripts/force_stale.sql`), `dbt build --select stg_orders` still returns `Done. PASS=10 … ERROR=0`, exit 0, and prints no freshness step. `target/sources.json` is not rewritten | full |
| Seeing the **stale** outcome | `scripts/force_stale.sql` shifts every `loaded_at` backwards; `scripts/restore_freshness.sql` shifts it forward again, exactly reversibly | `psql -f scripts/force_stale.sql && dbt source freshness` → 5 × `ERROR STALE`, exit 1. Then `psql -f scripts/restore_freshness.sql && dbt source freshness` → 5 PASS, exit 0 | full |
| `sources.json` | written **only** by `dbt source freshness` — not by `run`, `build`, `parse` or `ls` | `bash scripts/save-baseline.sh --rebase` runs each producer and copies its artifact out immediately. It accepts freshness exit 1 only with every expected source present exactly once, verdict statuses, and an `error`; it rejects a failed `product_catalog` query omitted from `sources.json` | full |
| `source_status:fresher+` | `scripts/rotate_loaded_at.sql` bumps `loaded_at` on the 50 lowest `order_id`s | **four steps, not two** — see below | full |

The `source_status:fresher+` recipe needs a freshness run on *each* side of the mutation. Run
without the middle two steps it prints `No nodes selected!`:

```bash
bash scripts/save-baseline.sh --rebase          # 1. baseline, including sources.json
psql -f scripts/rotate_loaded_at.sql            # 2. make one source fresher
dbt source freshness                            # 3. record the new state
dbt ls --select source_status:fresher --state ./prior-artifacts --resource-type source
                                                # 4. -> source:dbtae_companion.raw_ecom.orders
dbt ls --select source_status:fresher+ --state ./prior-artifacts
                                                #    -> 64 nodes
```

---

## Domain 7 — Leveraging the dbt state

*Formerly Topic 8. Two bullets: state **and state selection**, and `dbt retry`.*

### 7.0 The artifacts, and who writes them

Four artifacts, **four different producers**. A naive "run everything, then copy `target/`"
baseline ends up mixed-vintage, with a `run_results.json` from whatever ran last — a real CI
failure mode, and the reason `scripts/save-baseline.sh` copies each artifact out immediately
after the command that produces it.

| Artifact | Written by | Not written by |
|---|---|---|
| `manifest.json` | almost every command | — |
| `run_results.json` | `run`, `build`, `test`, `seed`, `snapshot`, `compile`, `show`, `run-operation`, `clone`, `retry`, `docs generate` | `ls`, `parse`, `source freshness` |
| `sources.json` | `source freshness` **only** | everything else |
| `catalog.json` | `docs generate` **only** | everything else |

```
dbt build            -> cp manifest.json, run_results.json
dbt source freshness -> cp sources.json
dbt docs generate    -> cp catalog.json
```

### 7.1 State and state selection

`prior-artifacts/` is **gitignored**, so a fresh clone does not receive a baseline. What ships
instead is `scripts/baseline-preimage/` — a committed description of a deliberately *earlier*
project state, with a sha256 drift guard per file. `bash scripts/save-baseline.sh --rebase`
stages that preimage, builds, and restores the working tree through a `trap`, producing a
baseline whose delta against HEAD is a small, realistic pull request:

- `stg_products` stops doing its own cents→dollars arithmetic and calls the shared
  `cents_to_dollars()` macro — a **value-neutral** refactor, which is exactly the kind CI exists
  to check;
- the singular test `assert_large_orders_within_review_tolerance` is new.

`bash scripts/save-baseline.sh` with no argument snapshots the *current* state instead, which is
what you want before making your own edit. It prints a warning that `state:modified` will select
nothing until you change something.

| Concept | Command | Result | Status |
|---|---|---|---|
| `state:modified` | `dbt ls --select state:modified --state ./prior-artifacts` | 8 under the default `eager` indirect selection; **2** under `--indirect-selection empty` (`stg_products` plus the new test). The six generic tests on `stg_products` come along because their parent was selected — same selector, different number | full |
| `state:new` | `dbt ls --select state:new --state ./prior-artifacts` | 1 (the new test) | full |
| `state:old` / `state:unmodified` | `dbt ls --select state:old --state ./prior-artifacts --indirect-selection empty` | 124 old and 123 unmodified, out of 125 selectable | full |
| `state:modified+` | `dbt ls --select state:modified+ --state ./prior-artifacts --resource-type model` | `stg_products`, `int_order_items_enriched` (ephemeral, in the subtree), `dim_products`, `fct_order_items` | full |
| `state:modified.body` | `dbt ls --select state:modified.body --state ./prior-artifacts` | `stg_products` + its tests + the new test. **Only `.body` isolates the real code change** | full |
| `state:modified.configs` / `.relation` / `.persisted_descriptions` / `.contract` | the same shape | the new test only — a node absent from the baseline counts as modified under *every* sub-method, which is why it appears in five of the six | full |
| `state:modified.macros` | `dbt ls --select state:modified.macros --state ./prior-artifacts` | `No nodes selected!` — nothing about macros changed. The honest null | full |
| What `state:modified` **excludes** | patch one key at a time in `models/marts/_marts__models.yml` and re-run `dbt ls --select state:modified` / `.configs` / `.relation` | measured 2026-09-02 against a matched `dbt parse` baseline: a model-level **`tags`** change selects **nothing**; a **`group`** reassignment selects **nothing**; a model-level **`meta`** change selects the model under *both* `state:modified` and `.configs`; **`alias`** and **`schema`** are excluded from `.configs` and caught by **`.relation`**. Edit `dim_pii_customers` in YAML and nothing happens — its `access`/`group` come from an inline `config()` block that wins | full (by edit) |
| What `state:modified` **catches** beyond code | same method | `access` (`dim_products` → `public`), `deprecation_date`, `latest_version` (on `dim_customer_segments`, selecting both versions), source `freshness` thresholds, and exposure `maturity` all fire | full (by edit) |
| Rendered vs unrendered config at the 1.11 default | `dbt parse` a baseline, then `dbt ls --select state:modified.configs --state <baseline> --vars '{start_date: "2025-02-01"}'` | `fct_orders_microbatch` (its `begin` is `var('start_date')`) plus its tests. Add `state_modified_compare_more_unrendered_values: true` to `flags:` **and rebuild the baseline** and the same command prints `No nodes selected!` — the unrendered value never changed. The flag defaults **false** at 1.11 | full |
| Stale baseline → false positives | set that flag with the **old** baseline still in place | 51 nodes selected instead of 5. The baseline has no `unrendered_config` to compare against, so nearly everything looks modified. This is the CI failure the docs warn about, reproduced in one line. The flag is **not** settable by env var — `DBT_STATE_MODIFIED_COMPARE_MORE_UNRENDERED_VALUES=True` has no effect; it must go in `dbt_project.yml` | full |
| `state:modified` is blind to data | `psql -f scripts/mutate-customers.sql` between two identical `dbt ls --select state:modified` runs | same count before and after (45 / 45). New or changed rows never make a model modified | full |
| `catalog.json` is not read by state | `cp -r prior-artifacts /tmp/s && rm /tmp/s/catalog.json`, then run the same `state:modified` against each | byte-identical selections. A clean negative fact | full |
| `--state` and `--target-path` pointing at the same directory | `dbt ls --select state:modified --state ./target --target-path ./target` after an edit | `No nodes selected!` — even on the first run. dbt overwrites `manifest.json` while parsing, so the comparison is against the *new* manifest. Point them at the same path and every state feature quietly stops working | full |
| `--defer` requires a state directory | `dbt run --select stg_products --defer` | `Runtime Error / --state or --defer-state are required for deferral, but neither was provided`, exit **2**. It does not no-op. Note `dbt ls --defer` exits 0 — `ls` executes nothing, so it never defers | full |
| `--defer-state` as a separate manifest | `dbt compile --target ci --select fct_daily_sales --defer --defer-state ./prior-artifacts` (no `--state`) | exit 0; `ref('fct_orders')` resolves to `"dbtae"."dev"."fct_orders"`. `--state` and `--defer-state` can name different directories in one command | full |
| `DBT_ENGINE_STATE` (1.11 name) | `DBT_ENGINE_STATE=./prior-artifacts dbt ls --select state:new` | works; the legacy `DBT_STATE` still works too; and `--state ./prior-artifacts` overrides a bogus `DBT_ENGINE_STATE=./nonexistent-dir` — flag beats env var | full |
| Which commands write `manifest.json` | `rm target/manifest.json`, run one command, look | `deps` → none, `debug` → none, `parse` / `compile` / `ls` → written | full |
| `1+result:fail` vs `result:fail+` | after the injected failure, `dbt ls --select '1+result:fail' --state ./target --vars '{force_test_fail: true}'` | `result:fail+` → the failed test alone (1). `1+result:fail` → 15, and `fct_orders` — **the model behind the test** — is in it. That is the rebuild idiom. `result:pass` also exists → 84 | full |
| Seeds above ~1 MiB are diffed by path, not content | generate `seeds/big.csv` (>1 MiB) and `seeds/small.csv`, `dbt parse` a baseline, change one value in **each**, re-select | measured 2026-09-02: a 1,398,901-byte seed is **not** selected; an 8,901-byte seed with the identical edit **is**. Not shipped — a 1.4 MB fixture would buy one row and cost every clone | skip — recipe, not fixture |
| `--selector slim_ci` | `dbt ls --selector slim_ci --state ./prior-artifacts` | 17 nodes, identical to `state:modified+` | full |
| `--defer` + `--state` (slim CI) | `bash scripts/slim-ci.sh` | `Done. PASS=17 WARN=0 ERROR=0 SKIP=0 NO-OP=1 TOTAL=18`. The warehouse proves the deferral: `ci` afterwards holds **three** relations (`stg_products`, `dim_products`, `fct_order_items`), not eighteen | full |
| `--favor-state` | `dbt compile --target ci --select fct_daily_sales --defer --state ./prior-artifacts` | **Precondition: `ci.fct_orders` must exist**, so run `dbt build --target ci --full-refresh` first. Then `ref()` resolves to `"dbtae"."ci"."fct_orders"` — the local relation wins, which is the default — and adding `--favor-state` resolves it to `"dbtae"."dev"."fct_orders"`, the deferred relation. Run this straight after `scripts/slim-ci.sh` instead and **both halves print `dev`**: `slim-ci.sh` builds three relations and `fct_orders` is not one of them, so there is no local relation for the default to prefer and the contrast disappears | full (with the precondition) |
| `result:` selectors | `dbt build --vars '{force_test_fail: true}'`, then `dbt build --select result:fail+ --state ./target --vars '{force_test_fail: true}'` | exit 1, `TOTAL=3`. Node counts for the other two, measured with `dbt ls` and the same two arguments: `result:skipped+` → 10, `result:success` → 85. As `dbt build` they report `TOTAL=12` and `TOTAL=87`, because a build adds the two project hooks and pulls in each selected model's tests | full, with the caveats below |
| `result:error+` | — | **selects nothing here.** See below | skip |
| CI artifact-store pattern | `scripts/slim-ci.sh` simulates download → build-diff → upload using the local `prior-artifacts/` directory | | full |

**`result:` — read this before using it.** Three things bite, and they bite independently:

1. `dbt build --select result:error+` with no `--state` fails outright with `Internal Error / No
   comparison run_results`. `result:` needs a prior-run artifact directory, and the previous
   run's is `./target`.
2. A **data test that returns failing rows has status `fail`, not `error`.** `error` is for a
   node that raised. Measured statuses after the injected failure:
   `{'success': 22, 'pass': 86, 'no-op': 1, 'fail': 1, 'skipped': 10}`. So `result:fail+`
   selects the failing test and `result:error+` selects nothing.
3. The failing test is `enabled:`-gated on `force_test_fail`, so **the selecting command must
   pass the var too**. Without it the node is not in the current manifest and cannot be selected
   at all.

### 7.2 `dbt retry`

| Concept | Command | Result | Status |
|---|---|---|---|
| `dbt retry` after a failed build | `dbt build --vars '{force_test_fail: true}'`, then `dbt retry` | exit 1; replays the previous run's `--vars`; `Done. PASS=2 WARN=0 ERROR=1 SKIP=10 NO-OP=0 TOTAL=13` | full |
| Flags `dbt retry` **rejects** | `dbt retry --select fct_orders` | `Error: No such option: --select`, exit **2**. `retry` replays the recorded invocation; it does not let you **re-scope** it. `--exclude` and `--selector` are refused the same way | full |
| `dbt retry` with nothing to resume | `dbt build` (clean), then `dbt retry` | `Nothing to do. Try checking your model configs and model specification args`, exit **0** — a successful prior run makes retry a no-op | full |
| `dbt retry` when `target/` holds no run | **`rm -rf target`**, then `dbt ls`, then `dbt retry`; or point `POSTGRES_PORT` at a closed port on a clean target, `dbt run`, then `dbt retry` | `Runtime Error / Could not find previous run in 'target' target directory`, exit **2**. The `rm -rf` is the precondition, not decoration: `ls` writes no `run_results.json` but it does not remove one either — measured on 1.11.14, an existing file comes back byte-identical — so `dbt ls; dbt retry` on a built target replays the *earlier* build's results and prints `Nothing to do`, exit **0**. It is the absence of the artifact that raises the error, never `ls` itself | full |
| Flags `dbt retry` accepts | `dbt retry --full-refresh` | accepted — `dbt retry --help` lists `-f, --full-refresh`. After the injected failure it returns `Done. PASS=2 WARN=0 ERROR=1 SKIP=10 NO-OP=0 TOTAL=13`, exit **1**: that is the replayed failure, not a CLI rejection. `--threads`, `--vars` and `--target` are likewise accepted, but are not individually exercised here | full for `--full-refresh`; partial (not exercised) for the rest |

---

## What this repo cannot demonstrate

Two different reasons, kept apart on purpose. Conflating them makes the repo look as though it
is failing to cover assessed material when it is not.

### In scope for the exam, but blocked by the adapter

| # | Item | Why, and what to recall instead |
|---|---|---|
| 1 | **Python models** | dbt-postgres has no Python runtime. Recall: a `.py` file under `models/`, `def model(dbt, session)`, `dbt.ref()` instead of Jinja `{{ ref() }}`, `dbt.config(packages=[…])`, materializations limited to `table` / `incremental`. Snowflake / Databricks / BigQuery only |
| 2 | **`incremental_strategy: insert_overwrite`** | Partition-aware adapters (BigQuery / Spark / Databricks). Recall: used with `partition_by`, replaces whole partitions, common for date-partitioned fact tables |
| 3 | **Zero-copy `dbt clone` semantics** | The *command* runs here and produces queryable clones, but dbt-postgres creates pointer views. Divergent writes to a clone — the Snowflake / Databricks primitive — cannot be shown |
| 4 | **Adapter DDL variance for `persist_docs`** | Postgres emits `COMMENT ON`; other adapters differ |
| 5 | **Adapter variance in constraint *enforcement*** | Postgres enforces all five constraint types for real. Many cloud warehouses treat `primary_key` / `foreign_key` / `unique` as metadata-only. This repo is the most honest place to watch enforcement and the least representative of cloud production |
| 6 | **dbt Mesh / cross-project `ref()`** | Needs two projects. Model `access` and `groups` — the single-project half — are fully covered in [Domain 2](#domain-2--managing-dbt-models-governance) |
| 7 | **`dbt init`** | Creates new projects; there is nothing to demonstrate inside an existing one |

### Not on the current exam outline at all

These are absent from the current study guide's topics and learning path, so they are not
uncovered test points — they are out of scope. Listed only so a reader does not go looking:

dbt Cloud jobs, environments, scheduler and Git integration; dbt Studio; the Semantic Layer,
MetricFlow and saved queries; dbt Catalog / Explorer / Canvas / Insights; Delta Lake features
(`tblproperties`, CDF, deletion vectors, `file_format: delta`); Unity Catalog features (column
masks, `+databricks_tags:`, multi-catalog nesting via `+database:`).

---

## Repo file layout

```
dbt-analytics-engineer-certification/
├── .devcontainer/
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── post-create.sh
│   ├── post-start.sh
│   ├── README.md                    # the verification suite, documented
│   ├── _runner.sh                   # profile wrapper: puts profiles.yml in place, then execs
│   ├── _test_exercises.sh           # all 22 triage cases; asserts exit code + layer + message/manifest
│   ├── _check_grants.sh
│   ├── _clone_test.sh               # re-runnable: drops leftover clones by relkind
│   ├── _mv_verify.sh
│   ├── _verify_disabled.sh
│   └── _verify_identifier.sh
├── .dbtignore                       # _scratch/ and exercises/ (second guard, not the mechanism)
├── .env.example                     # env vars consumed by profiles + sources
├── .gitattributes                   # keeps *.sh and .devcontainer/** at LF
├── .gitignore                       # target/, logs/, dbt_packages/, prior-artifacts/, .venv/, profiles.yml
├── LICENSE
├── README.md                        # 1-click run instructions + guided command sequence
├── RELEASE-NOTES-1.11.md            # what the 1.11 upgrade changed
├── REPO-COVERAGE.md                 # this file
├── dbt_project.yml
├── package-lock.yml                 # committed; carries godatadriven/dbt_date transitively
├── packages.yml
├── profiles.yml.example             # the devcontainer copies a real one to ~/.dbt/
├── requirements.txt                 # dbt-core==1.11.14, dbt-postgres==1.11.0
├── selectors.yml                    # nightly_core, slim_ci, critical_only
├── assets/
│   └── front-cover.png
├── db-init/                         # mounted to postgres /docker-entrypoint-initdb.d/
│   ├── 01-roles.sql                 # bi_reader, analytics_reader, finance_reader, marketing_reader
│   ├── 02-schemas.sql               # raw_ecom, raw_ref only — dbt creates its own target schemas
│   ├── 03-raw-tables.sql            # DDL for the raw tables + loaded_at columns
│   └── 04-load-raw.sql              # \COPY from data-seed/*.csv
├── data-seed/                       # CSVs loaded into Postgres on first boot
│   ├── GENERATED.md                 # the fixture's time window — read before writing a --sample window
│   ├── customers.csv                # 200 rows; mutable email/address for the snapshot demo
│   ├── products.csv                 # 50 rows
│   ├── orders.csv                   # 4,000 rows, including future-dated scheduled orders
│   ├── order_items.csv              # 10,386 rows
│   ├── audit_events.csv             # 6,000 rows, at least one per calendar day
│   └── currency_rates.csv           # 5 rows
├── seeds/                           # dbt seeds (reference data, distinct from sources)
│   ├── country_codes.csv
│   └── product_categories.csv
├── models/
│   ├── sources.yml                  # raw_ecom + raw_ref; freshness, event_time, source tests
│   ├── _groups.yml                  # pii, marketing, finance (finance has no members)
│   ├── exposures.yml                # dashboard, ml, analysis
│   ├── docs/
│   │   └── glossary.md              # 3 {% docs %} blocks, all referenced
│   ├── staging/
│   │   ├── _staging__models.yml     # column tests, descriptions, unit_tests
│   │   ├── stg_customers.sql        # view; dbt_utils.generate_surrogate_key
│   │   ├── stg_products.sql
│   │   ├── stg_orders.sql           # event_time: created_at; dbt_utils.star; audit_columns
│   │   ├── stg_order_items.sql      # deliberately NO event_time — the --sample lesson
│   │   ├── stg_audit_events.sql     # limit_data_in_dev
│   │   └── stg_currency_rates.sql
│   ├── intermediate/
│   │   └── int_order_items_enriched.sql   # ephemeral
│   └── marts/
│       ├── _marts__models.yml       # contracts, constraints, versions, unit_tests
│       ├── _example_disabled.sql    # enabled: false
│       ├── dim_customers.sql        # table
│       ├── dim_products.sql         # table + contract + pk / unique / check / not_null
│       ├── dim_customer_segments_v1.sql
│       ├── dim_customer_segments_v2.sql
│       ├── dim_pii_customers.sql    # access: private, group: pii
│       ├── fct_orders.sql           # incremental delete+insert; access: public; grants
│       ├── fct_order_items.sql      # incremental merge; composite key; contract; on_schema_change: fail
│       ├── fct_orders_microbatch.sql # incremental microbatch; event_time; begin=var('start_date')
│       ├── fct_daily_sales.sql      # incremental delete+insert; on_schema_change: ignore
│       ├── fct_audit_events.sql     # incremental append; full_refresh: false
│       ├── fct_segment_activity.sql # ref(v=1); carries the foreign_key constraint
│       └── mv_recent_orders.sql     # materialized_view; dbt issues the REFRESH
├── snapshots/
│   ├── _snapshots.yml               # snp_products_yaml — YAML form, explicit check_cols list
│   ├── snp_customers_timestamp.sql  # SQL-block form, timestamp strategy
│   └── snp_products_check.sql       # SQL-block form, check_cols='all', hard_deletes
├── tests/
│   ├── assert_no_future_orders.sql                       # store_failures, limit, tags
│   ├── assert_fct_orders_amount_matches_items.sql        # fail_calc override + the zero-row trap
│   ├── assert_large_orders_within_review_tolerance.sql   # warn_if / error_if
│   ├── fixtures/                                         # unit-test fixture CSVs
│   │   ├── unit_stg_orders_eur.csv
│   │   ├── unit_dim_customers_de.csv
│   │   ├── unit_stg_currency_rates_eur.csv
│   │   └── unit_fct_orders_usd_expected.csv
│   └── generic/
│       ├── test_value_in_range.sql
│       └── not_null.sql                                  # shadows the built-in, project-wide
├── macros/
│   ├── audit_columns.sql            # run_started_at + target metadata
│   ├── cents_to_dollars.sql
│   ├── limit_data_in_dev.sql        # branches on target.name
│   ├── date_trunc_day.sql           # dispatch: default__ + postgres__
│   ├── demo_exceptions.sql          # the four exceptions.* functions, behind {% if execute %}
│   ├── generate_surrogate_key.sql   # defines default__generate_surrogate_key
│   ├── get_custom_schema.sql        # generate_schema_name override
│   ├── grant_select.sql             # run-operation target
│   └── query_comment.sql            # JSON query comment
├── analyses/
│   └── compare_fct_orders_versions.sql   # audit_helper.compare_relations, two real relations
├── exercises/                       # 22 broken cases — outside every *-paths
│   ├── README.md                    # catalogue + the one trigger flow
│   ├── cyclic/
│   ├── ref_typo/
│   ├── ref_disabled/
│   ├── ref_bad_version/
│   ├── contract_drift/
│   ├── constraint_missing_data_type/
│   ├── source_misresolved/
│   ├── access_violation/
│   ├── public_ephemeral/
│   ├── macro_undefined/
│   ├── macro_arity/
│   ├── unquoted_macro_arg/          # unquoted arg = undefined Jinja var; fails in the warehouse
│   ├── hardcoded_relation/          # no ref(), no DAG edge
│   ├── depends_on_comment/          # -- depends_on: works, {# depends_on: #} does not
│   ├── conditional_ref/             # ref() in an unrendered branch; two graphs, one file
│   ├── test_config_not_nested/      # test config beside the test name instead of under config:
│   ├── dispatch_miss/               # has a macros/ sub-directory
│   ├── jinja_unbalanced/
│   ├── yaml_indent/
│   ├── yaml_wrong_type/
│   └── yaml_unknown_key/
├── scripts/
│   ├── generate_data.py             # regenerates data-seed/ from an anchor date
│   ├── save-baseline.sh             # --rebase builds the teaching baseline from the preimage
│   ├── baseline-preimage/           # committed pre-change state + sha256 drift guard
│   │   ├── PREIMAGE
│   │   ├── README.md
│   │   └── files/models/staging/stg_products.sql
│   ├── slim-ci.sh                   # state:modified+ --defer --state
│   ├── clone-demo.sh                # dbt clone against prior-artifacts
│   ├── mutate-customers.sql         # snapshot SCD2 demo
│   ├── rotate_loaded_at.sql         # source_status:fresher+ demo
│   ├── force_stale.sql              # make source freshness ERROR
│   ├── restore_freshness.sql        # and put it back, exactly
│   ├── reset-warehouse.sh           # reload raw_ecom/raw_ref from data-seed/, drop the
│   │                                #   project's schemas, rebuild. The only way back from
│   │                                #   a source UPDATE or accumulated snapshot history
│   └── check_receipts.py            # re-measures every receipt the docs quote and diffs it
└── prior-artifacts/                 # created by save-baseline.sh; GITIGNORED, never shipped
```

---

## Design notes

1. **Broken examples.** `exercises/` sits outside every `*-paths` entry in `dbt_project.yml`,
   which is what keeps `dbt build` green with twenty-two broken files in the repo. The `.dbtignore`
   line is a second guard that starts mattering the day someone widens `model-paths`.
   `enabled: false` would not do the job: it cannot protect a project from parse-fatal files
   (cyclic refs, Jinja and YAML syntax errors, access validation). The reader copies a case into
   `models/_tmp_broken/`, runs one command, and deletes the directory — `models/_tmp_broken/` is
   **not** in `.gitignore`, so an abandoned exercise shows up as untracked junk and as a broken
   node in the next build. See `exercises/README.md`.

2. **State demos.** `prior-artifacts/` is gitignored and never shipped, so a fresh clone must run
   `bash scripts/save-baseline.sh --rebase` before any `state:`, `--defer` or `clone` demo. What
   *is* committed is `scripts/baseline-preimage/` — the pre-change project state the baseline is
   built from, with a sha256 drift guard, so editing `stg_products.sql` without re-deriving the
   preimage aborts with instructions instead of silently baselining a delta nobody designed.

3. **Synthetic data.** Generated once by `scripts/generate_data.py` (stdlib only, fixed random
   seed) and committed as CSVs, which are the source of truth. The generator cuts timestamps
   relative to an anchor date rather than to fixed calendar dates, which is why `source
   freshness` passes on a fresh clone. `data-seed/GENERATED.md` records the window — read it
   before writing any `--sample` window or quoting a row count.

4. **Row counts move.** Several relations grow with wall-clock time: `fct_orders`,
   `fct_orders_microbatch` and `fct_daily_sales` as scheduled orders mature; `mv_recent_orders`,
   `stg_audit_events` and `fct_audit_events` as rolling windows slide. Prefer "about 1,800 and
   growing" to a fixed number, or state the measurement date. Two drills are also one-way:
   `scripts/mutate-customers.sql` takes `snp_customers_timestamp` from 200 rows to 201, and
   `scripts/rotate_loaded_at.sql` bumps 50 orders' `loaded_at`.

5. **Incremental strategies.** Four are demonstrated — `append`, `delete+insert`, `merge` and
   `microbatch` — with a shape → strategy mapping in
   [§1.5](#15-choosing-an-incremental-strategy). On dbt-postgres both `merge` and `microbatch`
   compile to `merge into …`, which is why Postgres 15 is the floor and why the microbatch model
   must declare a `unique_key`. `insert_overwrite` is partition-aware-adapter territory.

6. **Profiles.** `profiles.yml.example` lives in the repo. `.devcontainer/Dockerfile` only
   creates `~/.dbt`; the copy into `~/.dbt/profiles.yml` is done by `.devcontainer/post-create.sh`
   (and by `.devcontainer/_runner.sh` outside the container). The file is copied verbatim — its
   `{{ env_var(...) }}` calls are resolved by dbt at run time from the environment
   `docker-compose.yml` sets, not substituted at copy time. The repo stays credential-free, and
   a real `profiles.yml` is gitignored.

7. **Postgres role demo.** `db-init/01-roles.sql` must create the roles before any `GRANT` runs.
   The init-scripts contract guarantees it: they run once, before Postgres accepts outside
   connections, so the roles exist by the time `docker compose up` finishes.

8. **Version pins.** `requirements.txt` pins `dbt-core==1.11.14` and `dbt-postgres==1.11.0`, and
   `dbt_project.yml` carries `require-dbt-version: [">=1.11.0", "<1.12.0"]`, so a mismatched
   environment fails at parse rather than somewhere subtler.

9. **The verification suite.** `.devcontainer/` ships six checking scripts —
   `_test_exercises.sh` (all twenty-two triage cases), `_check_grants.sh`, `_mv_verify.sh`,
   `_verify_identifier.sh`, `_verify_disabled.sh` and `_clone_test.sh` — plus `_runner.sh`, which
   checks nothing: it puts `profiles.yml` in place and execs whatever you hand it. All seven are
   documented in `.devcontainer/README.md`. Every one is re-runnable, including `_clone_test.sh`,
   which has to dispatch on relation kind to stay that way — see [Domain 4](#42-dbt-clone).
