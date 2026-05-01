# REPO-COVERAGE.md

Build spec for this companion repo. Each row maps an exam concept to the repo artifact that demonstrates it. Readers run `dbt` against the artifact; the repo stays credential-free and standalone.

## Stack assumptions

- Python 3.11
- `dbt-core==1.8.9`, `dbt-postgres==1.8.2` (last stable 1.8 patches as of mid-2025; verify on PyPI if pip errors)
- Postgres 15 (for native `MERGE` support used by the `merge` incremental strategy)
- Linux container (devcontainer), no Windows path assumptions

**Why 1.8 and not 1.7 (book target):** The V.9.0 exam blueprint is calibrated to dbt Core 1.7. Every 1.7 concept the exam tests runs identically on 1.8, and 1.8 gains two *runnable* demos the companion would otherwise have to skip: native Postgres `MERGE` (incremental strategy) and native `unit_tests:` YAML. The README carries a 1-paragraph note explaining the version choice. Book content is unaffected; the book's "post-1.7 sidebar" banners remain correct.

## How to read this document

- **"Concept"** — the exam-relevant primitive as taught in the dbt Certification V.9.0 blueprint.
- **"Repo artifact"** — the file or directory where the concept is exercised.
- **"Command to try"** — the CLI invocation that makes the concept observable.
- **"Status"** — `full` (runs end-to-end), `partial` (runs with an adapter caveat, documented), or `skip` (Postgres can't demonstrate it; covered by README pointer only).

---

## Domain 1 — Developing dbt models

### 1.1 Project scaffolding & configuration

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `dbt_project.yml` with `name`/`version`/`profile` | `dbt_project.yml` | `dbt parse` | full |
| `require-dbt-version` pin | `dbt_project.yml` (`require-dbt-version: ">=1.8.0,<1.9.0"`) | `dbt parse` after bumping dbt | full |
| Path keys (`model-paths`, `seed-paths`, etc. — all listed explicitly) | `dbt_project.yml` | `dbt debug` | full |
| `clean-targets` | `dbt_project.yml` (`["target","dbt_packages"]`) | `dbt clean` | full |
| Project-level `vars:` | `dbt_project.yml` (`vars.start_date`) | `dbt compile --select model_using_var` | full |
| `on-run-start` / `on-run-end` hooks | `dbt_project.yml` (log on start; result-count log on end) | any `dbt run` | full |
| `pre_hook` / `post_hook` at model level | `models/marts/fct_orders.sql` (post_hook = `analyze {{ this }}`) | `dbt run --select fct_orders` | full |
| Config precedence: project `+config` vs inline `{{ config() }}` | `models/staging/stg_customers.sql` (inline `config(materialized='view', tags=[...])` coexists with the project-level `staging: +materialized: view` / `+tags: ['staging']`; inline wins on tie and would override the folder default if they differed). YAML `config:` is a valid third layer but isn't used here — reader can add one to `_staging__models.yml` to exercise it | `dbt compile --select stg_customers` + inspect `target/compiled/` | partial |

### 1.2 Models, `ref()`, and the DAG

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `ref()` between models | every `models/**/*.sql` except staging | `dbt ls --select +fct_orders` | full |
| Staging → intermediate → marts layering | `models/staging/`, `models/intermediate/`, `models/marts/` | `dbt build` | full |
| `{{ this }}` self-reference | `models/marts/fct_daily_sales.sql` (incremental filter) | `dbt run --select fct_daily_sales` | full |
| `{{ target.name / schema / database }}` | `macros/audit_columns.sql` (emits target metadata) | `dbt compile --select any_model_using_audit_columns` | full |
| `run_started_at` | `macros/audit_columns.sql` | compile | full |
| `env_var()` | `profiles.yml.example` + `models/sources.yml` (`database: "{{ env_var('RAW_DATABASE','dbtae') }}"`) | `dbt debug` | full |
| `adapter.dispatch()` | `macros/date_trunc_day.sql` (project dispatch + `postgres__` + `default__`) | `dbt run --select fct_daily_sales` | full |
| Circular dependency | `exercises/cyclic/` (gated via `.dbtignore` — copy into `models/` to trigger) | `dbt compile` after copy | full |

### 1.3 Sources and freshness

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `sources:` YAML at `(database, schema)` granularity | `models/sources.yml` (2 sources sharing `raw` DB, different schemas: `raw_ecom`, `raw_ref`) | `dbt ls --resource-type source` | full |
| `source()` Jinja function | every `stg_*.sql` | compile | full |
| `identifier:` override | `models/sources.yml` (`product_catalog` YAML entry with `identifier: products`, exposing the warehouse table under a different dbt-facing name) | `dbt run --select stg_products` | full |
| `env_var()` inside source `database:` | `models/sources.yml` | `dbt debug` | full |
| Source-column tests (`not_null`, `unique`, `relationships`) | `models/sources.yml` | `dbt test --select source:*` | full |
| Source-level `loaded_at_field` + `freshness` | `models/sources.yml` | `dbt source freshness` | full |
| Table-level freshness override | `models/sources.yml` (`orders` tightens error_after) | `dbt source freshness --select source:raw_ecom.orders` | full |
| `freshness: null` opt-out | `models/sources.yml` (`audit_events` has `freshness: null`) | `dbt source freshness` (skipped) | full |
| `source_status:fresher+` selector | `scripts/rotate_loaded_at.sql` + `scripts/save-baseline.sh` | two-step: baseline then `dbt build --select source_status:fresher+ --state prior-artifacts` | full |

### 1.4 Materializations

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `view` (default) | `models/staging/*.sql` | `dbt run --select staging` | full |
| `table` | `models/marts/dim_customers.sql` | `dbt run --select dim_customers` | full |
| `ephemeral` | `models/intermediate/int_order_items_enriched.sql` | `dbt compile --select fct_orders` (inspect inlined CTE) | full |
| `incremental` with `unique_key` + `is_incremental()` guard + `on_schema_change` | `models/marts/fct_orders.sql` (`unique_key='order_id'`, `on_schema_change='append_new_columns'`) | `dbt run --select fct_orders` twice | full |
| Composite `unique_key` | `models/marts/fct_order_items.sql` (`unique_key=['order_id','line_no']`) | `dbt run --select fct_order_items` | full |
| `on_schema_change: ignore/fail/append_new_columns/sync_all_columns` | `models/marts/fct_orders.sql` comments document all four; `fct_order_items.sql` uses `sync_all_columns` | inspect | full |
| `incremental_strategy: append` | `models/marts/fct_audit_events.sql` | `dbt run --select fct_audit_events` | full |
| `incremental_strategy: delete+insert` | `models/marts/fct_orders.sql` | `dbt run --select fct_orders` | full |
| `incremental_strategy: merge` | `models/marts/fct_order_items.sql` (dbt-postgres 1.8 native MERGE on Postgres 15) | `dbt run --select fct_order_items` | full |
| `incremental_strategy: insert_overwrite` | README note: partition-aware adapters only | n/a | skip |
| `--full-refresh` | `fct_orders.sql` | `dbt run --select fct_orders --full-refresh` | full |
| `full_refresh: false` config (protect incremental from CLI full-refresh) | `models/marts/fct_audit_events.sql` | `dbt run --select fct_audit_events --full-refresh` (skips refresh) | full |
| Python models | README §"Python models" — Postgres does not support Python models | n/a | skip |
| `microbatch` strategy | README §"dbt 1.9+ features" — out of 1.7 scope | n/a | skip |
| `materialized_view` | `models/marts/mv_recent_orders.sql` (enabled; `on_configuration_change: apply`) | `dbt run --select mv_recent_orders` then `REFRESH MATERIALIZED VIEW dev.mv_recent_orders` to repopulate | full |

### 1.5 Snapshots

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Snapshot SQL-block syntax (1.7) | `snapshots/snp_customers_timestamp.sql` | `dbt snapshot` | full |
| `strategy: timestamp` + `updated_at` | `snapshots/snp_customers_timestamp.sql` | `dbt snapshot --select snp_customers_timestamp` | full |
| `strategy: check` + `check_cols=[...]` | `snapshots/snp_products_check.sql` | `dbt snapshot --select snp_products_check` | full |
| `strategy: check` + `check_cols='all'` | `snapshots/snp_products_check_all.sql` | same | full |
| `target_schema` | all three snapshot files | inspect | full |
| Generated columns (`dbt_valid_from`/`to`/`dbt_scd_id`/`dbt_updated_at`) | after running snapshots, `snapshots.snp_customers_timestamp` | `psql> \d snapshots.snp_customers_timestamp` | full |
| Scripted row mutation between runs | `scripts/mutate-customers.sql` (bumps one customer's email + updated_at) | `psql ... -f scripts/mutate-customers.sql && dbt snapshot` | full |
| `hard_deletes` / `invalidate_hard_deletes` | README note — dbt 1.9+ | n/a | skip |

### 1.6 Seeds

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Seed CSVs | `seeds/country_codes.csv`, `seeds/product_categories.csv` | `dbt seed` | full |
| `column_types` | `dbt_project.yml` (`seeds.country_codes.+column_types: {country_code: varchar(2)}`) | `dbt seed --full-refresh` | full |
| `quote_columns` | `seeds/product_categories.csv` + project config `+quote_columns: true` | `dbt seed` | full |
| `+schema:` override | `dbt_project.yml` (seeds → `reference` schema) | `dbt seed && psql \dn` | full |
| Seed vs source distinction | `seeds/` (reference data); `models/sources.yml` points at `raw_ecom.*` populated by `db-init/` | `dbt ls --resource-type seed` + `dbt ls --resource-type source` | full |

---

## Domain 2 — Model governance

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `contract: {enforced: true}` + typed `columns:` | `models/marts/dim_products.sql` + `models/marts/_marts__models.yml` | `dbt run --select dim_products` | full |
| Contract preflight failure | `exercises/contract_drift/` (gated via `.dbtignore`) | copy into `models/`, then `dbt run --select contract_drift` | full |
| `constraints:` (not_null) | `dim_products` column `product_id` | see above | full |
| `constraints:` (check) | `dim_products` column `price_usd` (`check: "price_usd >= 0"`) | INSERT negative → Postgres rejects | full |
| `constraints:` (primary_key) | `dim_products` (`constraints: [{type: primary_key, columns: [product_id]}]`) | `psql> \d+ marts.dim_products` | full |
| `constraints:` (foreign_key) | `models/marts/fct_order_items.sql` (FK to `dim_products.product_id`) | Postgres enforces | full |
| `constraints:` (unique) | `dim_products.sku` | Postgres enforces | full |
| Adapter variation (teaching) | README §"Constraints across adapters" table | n/a | partial (prose only) |
| Model `versions:` + `latest_version:` | `models/marts/dim_customer_segments.yml` (v1, v2, latest_version: 2) + `dim_customer_segments_v1.sql` + `_v2.sql` | `dbt run --select dim_customer_segments` | full |
| Per-version `columns:` override | same file | inspect | full |
| `ref('model', v=N)` consumer | `models/marts/fct_segment_activity.sql` uses `ref('dim_customer_segments', v=1)` | `dbt ls --select +fct_segment_activity` | full |
| `deprecation_date:` | `dim_customer_segments.yml` v1 with past date | `dbt parse` emits warning | full |
| `defined_in:` | `dim_customer_segments.yml` v1 uses `defined_in: dim_customer_segments_v1` | inspect | full |
| `access: private` | `models/marts/dim_pii_customers.sql` (group `pii`, private) | `dbt run` | full |
| `access: private` cross-group consumer failure | `exercises/access_violation/` (gated via `.dbtignore`; group `marketing` refs private pii model) | copy into `models/`, then `dbt parse` → `DbtReferenceError` | full |
| `access: protected` (default) | most marts | — | full |
| `access: public` | `models/marts/fct_orders.sql` | — | full |
| `access: public` + `ephemeral` disallowed | `exercises/public_ephemeral/` (gated via `.dbtignore`) | copy into `models/`, then `dbt parse` | full |
| `groups:` block with `owner:` | `models/_groups.yml` (`pii`, `marketing`, `finance`) | `dbt ls --select group:pii` | full |
| `group:` config on models | attached via YAML and `+group:` in project | | full |
| `grants:` on a model | `models/marts/fct_orders.sql` (`grants: {select: [bi_reader]}`) | `psql> \dp marts.fct_orders` | full |
| `+grants:` at project level | `dbt_project.yml` (`models.dbtae_companion.marts.+grants: {select: [analytics_reader]}`) | same | full |
| `'+select':` merge vs `select:` replace | `models/marts/fct_order_items.sql` uses `'+select': [finance_reader]` (merge with inherited) | `psql> \dp` shows 3 grantees | full |
| Pre-created Postgres roles | `db-init/01-roles.sql` (`bi_reader`, `analytics_reader`, `finance_reader`, `marketing_reader`) | auto on `docker compose up` | full |

---

## Domain 3 — Debugging

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `target/compiled/` inspection | any built model | `cat target/compiled/dbtae_companion/models/marts/fct_orders.sql` | full |
| `target/run/` inspection (DDL wrapper) | any `table`/`incremental` | `cat target/run/...` | full |
| `dbt compile --select <m>` narrow | any model | same | full |
| `dbt compile --inline "<sql>"` | exercised inline (no fixture needed) | `dbt compile --inline "select * from {{ ref('stg_orders') }} limit 1"` | full |
| Missing/typo `ref()` | `exercises/ref_typo/` (gated via `.dbtignore`) | copy into `models/`, then `dbt parse` | full |
| Disabled-upstream `ref()` | `exercises/ref_disabled/` | same flow | full |
| Wrong `ref('model', v=99)` | `exercises/ref_bad_version/` | same flow | full |
| Cyclic `ref()` | `exercises/cyclic/` (A↔B) | copy into `models/`, then `dbt compile` (cycles surface at topological sort, not parse) | full |
| YAML tab/indent/misplaced-key failures | `exercises/yaml/*.yml.broken` (files with `.broken` suffix; rename in place and temporarily drop `exercises/` from `.dbtignore`) | rename + remove ignore + `dbt parse` | partial (manual rename step) |
| Undefined macro error | `exercises/macro_undefined/` (calls `generate_surrogate_key(...)` without `dbt_utils.` prefix) | copy + `dbt compile --select macro_undefined` | full |
| Wrong macro arity | `exercises/macro_arity/` | same flow | full |
| Dispatch miss | `exercises/dispatch_miss/` (macro has `snowflake__` only, no `default__`) | same flow on Postgres | full |
| Unbalanced Jinja | `exercises/jinja_unbalanced/` | same flow | full |
| `dbt debug` | working profile | `dbt debug` | full |
| `--debug` flag / verbose logs | any command | `dbt --debug run --select one_model` | full |
| `logs/dbt.log` | default path | inspect after any run | full |
| `dbt build` short-circuit on failure | a singular test that fails when `--vars '{force_test_fail: true}'` | `dbt build --vars '{force_test_fail: true}'` → downstream skipped | full |
| Fix-before-merge workflow | README "triage cookbook" | prose | full |
| `--warn-error` CI gate | `dim_customer_segments.v1` has a past `deprecation_date`, which fires a parse-time WARNING on every run; `--warn-error` escalates it to a `Compilation Error` that halts the command | `dbt --warn-error parse` (prints "Encountered an error" / Compilation Error) vs `dbt parse` (prints WARNING and proceeds) | full |

---

## Domain 4 — Managing pipelines (CLI + selectors + orchestration)

### 4.1 Commands

| Command | Repo invocation | Status |
|---|---|---|
| `dbt run` / `build` / `test` / `seed` / `snapshot` / `compile` / `parse` / `deps` / `clean` / `retry` / `docs generate` / `docs serve` / `source freshness` / `ls` / `debug` / `run-operation` / `show` | all exercised in README command sequence | full |
| `dbt init` | README mention only (creates new projects) | skip |
| `dbt clone` | `scripts/clone-demo.sh` (uses saved baseline under `prior-artifacts/`); on Postgres the cloned relations are views pointing at the source schema (not zero-copy), but `dbt clone --target ci --state prior-artifacts --select fct_orders` completes successfully and the cloned relations are queryable | full (with Postgres-specific pointer-view semantics — not zero-copy) |

### 4.2 Node-selection methods

| Method | Where exercised | Status |
|---|---|---|
| default (`fqn`) | every `--select <name>` | full |
| `tag:` | `fct_orders` tagged `daily`; `fct_daily_sales` tagged `daily,critical` | full |
| `config.materialized:` | all models differ | full |
| `source:` | `models/sources.yml` | full |
| `path:` | `models/staging` etc. | full |
| `file:` | any `.sql` | full |
| `package:` | after `dbt deps` installs `dbt_utils` | full |
| `group:` | `group:pii`, `group:marketing` | full |
| `access:` | `access:public`, `access:private` | full |
| `test_name:` / `test_type:data` | built-in + custom tests | full |
| `test_type:unit` | one `unit_tests:` block (see Domain 5) | full |
| `resource_type:` | any resource class | full |
| `version:` | `version:latest` / `version:old` / `version:prerelease` / `version:none` — selects by semantic position, not numeric | full |
| `state:` / `result:` / `source_status:` / `exposure:` | see Domain 8 / Domain 6 | full |

### 4.3 Graph operators

| Operator | Exercised by | Status |
|---|---|---|
| `+model` / `model+` / `+model+` | DAG with 4+ layers: `raw → stg_* → int_* → fct_*/dim_* → snapshot/exposure` | full |
| `N+` / `+N` depth | same 4-layer DAG | full |
| `@model` | `relationships` test crossing staging → marts | full |
| `*` wildcard | `stg_*`, `tag:pii_*` | full |
| `,` intersection vs space union | README drill section | full |
| `--exclude` | README drill | full |

### 4.4 YAML selectors & global flags

| Item | Artifact | Status |
|---|---|---|
| `selectors.yml` | `selectors.yml` with 3 named selectors (`nightly_core`, `slim_ci`, `critical_only`) | full |
| `--selector <name>` | `dbt build --selector nightly_core` | full |
| Global flags `--full-refresh` / `--vars` / `--target` / `--threads` / `--profiles-dir` / `--project-dir` / `--fail-fast` / `--warn-error` / `--no-partial-parse` | scattered throughout README (`--warn-error` in §"Operations / debugging"; `--full-refresh` in §"Incremental strategies"; `--vars` in §"Your first 10 minutes"). No consolidated tour — each flag is shown where it's most useful | full |
| `.dbtignore` | `.dbtignore` ignores `_scratch/` and the whole `exercises/` tree | full |

---

## Domain 5 — Tests

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| Generic: `unique` | `stg_customers.customer_id` | `dbt test --select stg_customers` | full |
| Generic: `not_null` | many columns | same | full |
| Generic: `accepted_values` | `stg_orders.status` | same | full |
| Generic: `relationships` (→ `ref()`) | `fct_order_items.order_id → ref('fct_orders')` | same | full |
| Generic: `relationships` (→ `source()`) | `stg_orders.customer_id → source('raw_ecom','customers')` | same | full |
| Singular test with `ref()` | `tests/assert_fct_orders_amount_matches_items.sql` | `dbt test --select test_type:singular` | full |
| Singular test with `{{ config() }}` | `tests/assert_no_future_orders.sql` (`severity='warn', store_failures=true`) | same | full |
| Custom generic test (with args) | `tests/generic/test_value_in_range.sql` (`min_value`, `max_value`) | `dbt test --select test_name:value_in_range` | full |
| Test config: `severity` | `tests/assert_no_future_orders.sql` (`severity='warn'`) | `dbt test` | full |
| Test configs: `warn_if` / `error_if` | README note only — the pattern is documented but not wired into any test; reader can add one to any singular test to exercise it | n/a | skip (prose only) |
| Test config `store_failures: true` | `tests/assert_no_future_orders.sql` | after failure: `psql> select * from marts_dbt_test__audit.assert_no_future_orders` | full |
| Test config `store_failures_as: table` | same | same | full |
| Test config `where:` | `not_null` on `fct_orders.updated_at` with `where: "created_at >= current_date - interval '90 days'"` | full |
| Test config `limit:` | custom test with `limit: 500` | full |
| Project-wide test default (`data_tests: +severity: error, +store_failures: false`) | `dbt_project.yml` (these match the dbt-1.8 built-in defaults — the block is present to demonstrate where project-wide test configs live) | full |
| Test config precedence (inline overrides project) | `tests/assert_no_future_orders.sql` has `{{ config(severity='warn', store_failures=true) }}` — inline config overrides both the project-level default and the built-in | full |
| `test_type:generic` / `test_type:singular` selectors | README drill | full |
| Indirect selection modes (`eager`/`cautious`/`buildable`/`empty`) | README drill | full |
| `tag:` on tests | one test tagged `critical` | full |
| Unit tests (`unit_tests:` YAML) | `models/marts/_marts__models.yml` (`unit_tests:` block on `fct_orders` with `given:` + `expect:`) | `dbt test --select test_type:unit` | full (dbt 1.8+) |

---

## Domain 6 — Documentation

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `dbt docs generate` | any project state | `dbt docs generate` | full |
| `dbt docs serve` | after generate | `dbt docs serve --port 8080` (mapped in devcontainer) | full |
| `manifest.json` / `catalog.json` | `target/` | inspect | full |
| `--no-compile` / `--empty-catalog` flags | README | full |
| Model / column / source descriptions (all three levels) | `models/_marts__models.yml`, `_sources.yml` | docs site | full |
| Doc block `{% docs name %}` + `{{ doc('name') }}` | `models/docs/glossary.md` + refs from YAML | docs site | full |
| Markdown in descriptions (bold, list, link) | `docs/glossary.md` | docs site | full |
| `docs-paths:` | default `models/` | full |
| `persist_docs: {relation: true, columns: true}` | `dbt_project.yml` (global) | `psql> \d+ marts.fct_orders` shows COMMENT ON | full |
| Exposures with all fields | `models/exposures.yml` (one `dashboard`, one `ml`, one `application`) | `dbt ls --select +exposure:executive_kpi_dashboard` | full |
| `+exposure:` selector | `dbt build --select +exposure:ml_churn_model` | full |
| DAG navigation in docs site | generated | full |
| `enabled: false` removes from DAG | `models/marts/_example_disabled.sql` (discoverable by parse, excluded from build/docs) | `dbt ls --resource-type model` (absent from output) | full |
| `.dbtignore` excludes paths | see Domain 4 | full |
| `meta:` on resources + `+meta:` in project | `_models.yml` + `dbt_project.yml` | `grep meta target/manifest.json` | full |
| Databricks / Snowflake DDL variance for `persist_docs` | README note | skip (prose only) |

---

## Domain 7 — External dependencies

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `packages.yml` Hub source | `packages.yml` (`dbt-labs/dbt_utils`, `metaplane/dbt_expectations`, `dbt-labs/audit_helper`, `dbt-labs/codegen`) | `dbt deps` | full |
| Git source shape | `packages.yml` commented example | uncomment + `dbt deps` | partial (commented) |
| Local source shape | `packages.yml` commented example with `local: ../shared_pkg` | partial |
| Private / tarball shapes | README note only (needs auth) | skip |
| Exact + range version pins | `packages.yml` uses range for one, exact for another | full |
| `package-lock.yml` | committed after first `dbt deps`; includes `calogica/dbt_date` as a **transitive** dep of `metaplane/dbt_expectations` (not declared directly in `packages.yml`) | inspect | full |
| `dbt deps --upgrade` / `--lock` / `--add-package` | concept-only in this repo — run commands directly to exercise: `dbt deps --upgrade` (ignore lockfile), `dbt deps --lock` (regenerate lockfile only), `dbt deps --add-package dbt-labs/dbt_project_evaluator` | partial (no committed fixture) |
| `packages-install-path` | default `dbt_packages/` | `.gitignore` excludes | full |
| `dbt_utils.generate_surrogate_key` | `models/marts/dim_customers.sql` | `dbt run --select dim_customers` | full |
| `dbt_utils.star(from=..., except=[...])` | `models/staging/stg_orders.sql` | `dbt compile --select stg_orders` | full |
| `dbt_expectations.expect_column_values_to_match_regex` | `stg_customers.email` | `dbt test --select stg_customers` | full |
| `audit_helper.compare_relations` | `analyses/compare_fct_orders_versions.sql` | `dbt compile --select analysis:compare_fct_orders_versions && cat target/compiled/...` | full |
| `codegen.generate_source` | README example | `dbt run-operation codegen.generate_source --args '{schema_name: raw_ecom}'` | full |
| `dbt.generate_schema_name` override pattern | `macros/get_custom_schema.sql` | any `dbt run` shows custom schema naming | full |
| Dispatch override of a `dbt_utils` macro | `macros/dbtae_companion__generate_surrogate_key.sql` + `dispatch:` in `dbt_project.yml` | `dbt compile --select dim_customers` (inspect compiled SQL to see project macro won) | full |
| Source freshness (covered in 1.3) | — | — | full |

---

## Domain 8 — State and defer

| Concept | Repo artifact | Command | Status |
|---|---|---|---|
| `manifest.json` / `run_results.json` / `sources.json` / `catalog.json` | `target/` | inspect | full |
| `state:modified` / `state:modified+` | `scripts/save-baseline.sh` copies `target/` to `prior-artifacts/`; modify a model; re-run with `--state prior-artifacts` | README 2-step recipe | full |
| `state:modified.body` / `.configs` / `.relation` / `.persisted_descriptions` / `.macros` / `.contract` | README drill varying one facet at a time | each | full |
| `state:new` / `state:old` / `state:unmodified` | README drill adding a new model | full |
| `--defer` + `--state` | `scripts/slim-ci.sh` (the canonical slim-CI recipe) | `./scripts/slim-ci.sh` | full |
| `--favor-state` | README edge-case note | full |
| `result:error+` / `result:error` / `result:fail` / `result:skipped` / `result:warn` | after a `--vars '{force_test_fail: true}'` build | `dbt build --select result:error+` | full |
| State + result intersection / union | README drill | full |
| `source_status:fresher+` | `scripts/rotate_loaded_at.sql` bumps `loaded_at`; then `dbt source freshness` against prior | README 2-step | full |
| `dbt retry` | after broken-model failure, fix and `dbt retry` | full |
| `dbt retry` accepted flags (`--threads`/`--vars`/`--target`) and rejected (`--select`/`--full-refresh`) | README + intentional error demo | full |
| `dbt clone` (Postgres pointer-view) | `scripts/clone-demo.sh` — cloned relations are views in the target schema pointing at source-schema tables | full (pointer-view semantics; not Snowflake-style zero-copy) |
| CI artifact-store pattern (download → parse → build-diff → upload) | `scripts/slim-ci.sh` simulates this using local `prior-artifacts/` dir | full |

---

## Postgres out-of-scope items (skip list)

These exam concepts cannot be demonstrated naturally on Postgres. Each gets a README pointer to the official dbt docs; the book is the primary teaching surface.

1. **Python models** — Snowflake / Databricks / BigQuery only. Recall-only: `.py` file in `models/`, `def model(dbt, session)`, `dbt.ref()` vs Jinja `{{ ref() }}`, `dbt.config(packages=[...])`, materializations limited to `table`/`incremental`.
2. **`incremental_strategy: insert_overwrite`** — partition-aware adapters (BigQuery / Spark / Databricks). Recall: used with `partition_by`, replaces whole partitions, common for date-partitioned fact tables.
3. **`microbatch` strategy** — dbt 1.9+, out of 1.8 and out of 1.7 exam scope regardless.
4. **`hard_deletes` / `invalidate_hard_deletes` on snapshots** — dbt 1.9+.
7. **Delta Lake features** — `tblproperties`, CDF, deletion vectors, `file_format: delta`: Databricks-only.
8. **Unity Catalog features** — column masks (`ALTER TABLE ... SET MASK`), `+databricks_tags:`, multi-catalog nesting via `+database:`: Databricks-only.
9. **Snowflake / Databricks-Delta zero-copy `dbt clone` semantics** — the *command* runs on Postgres and produces queryable clones, but the cloned relations are pointer views, not true zero-copy clones. Divergent writes to a cloned table (a Snowflake/Databricks primitive) can't be demonstrated on Postgres.
10. **Snowflake / Databricks `persist_docs` DDL variance** — adapter-specific. Postgres emits `COMMENT ON`; README notes others differ.
11. **Adapter-specific constraint enforcement variance** — Postgres enforces `not_null`/`check`/`unique`/`primary_key`/`foreign_key` fully. Cloud warehouses often treat PK/FK/unique as metadata-only. The repo is actually the *most honest* place to observe enforcement; README flags that production cloud-warehouse behavior differs.
12. **dbt Cloud surfaces** — Cloud IDE, Cloud scheduler, Cloud environments, Cloud Git integration: not applicable to a Core-only devcontainer.
13. **dbt Mesh / cross-project `ref()`** — requires multiple projects. The repo demonstrates single-project `access` + `groups`.
14. **`dbt init`** — creates new projects; not demonstrable inside an existing repo. README mentions.

---

## Repo file layout

```
dbt-analytics-engineer-certification/
├── .devcontainer/
│   ├── devcontainer.json
│   ├── Dockerfile
│   └── docker-compose.yml
├── .dbtignore
├── .gitignore
├── .env.example                     # env vars consumed by profiles + sources
├── README.md                        # 1-click run instructions + command sequence
├── REPO-COVERAGE.md                 # this file
├── dbt_project.yml
├── packages.yml
├── profiles.yml.example             # devcontainer ships a real one to ~/.dbt/
├── requirements.txt                 # pinned dbt-core==1.8.9 + dbt-postgres==1.8.2
├── selectors.yml
├── db-init/                         # mounted to postgres /docker-entrypoint-initdb.d/
│   ├── 01-roles.sql                 # bi_reader, analytics_reader, finance_reader, marketing_reader
│   ├── 02-schemas.sql               # raw_ecom, raw_ref, marts, staging, snapshots
│   ├── 03-raw-tables.sql            # DDL for raw.* tables + loaded_at columns
│   └── 04-load-raw.sql              # \COPY from data-seed/*.csv
├── data-seed/                       # CSVs loaded into Postgres raw schema on first boot
│   ├── customers.csv                # ~200 rows, mutable email/address for snapshot demo
│   ├── products.csv                 # ~50 rows
│   ├── orders.csv                   # ~1000 rows with created_at, updated_at, loaded_at
│   ├── order_items.csv              # ~3000 rows
│   └── audit_events.csv             # ~500 rows for append-incremental demo
├── seeds/                           # dbt seeds (reference data, distinct from sources)
│   ├── country_codes.csv
│   └── product_categories.csv
├── models/
│   ├── sources.yml
│   ├── _groups.yml                  # pii, marketing, finance
│   ├── exposures.yml                # dashboard, ml, application
│   ├── docs/
│   │   └── glossary.md              # {% docs %} blocks
│   ├── staging/
│   │   ├── _staging__models.yml
│   │   ├── stg_customers.sql        # view
│   │   ├── stg_products.sql
│   │   ├── stg_orders.sql
│   │   ├── stg_order_items.sql
│   │   └── stg_audit_events.sql
│   ├── intermediate/
│   │   └── int_order_items_enriched.sql   # ephemeral
│   └── marts/
│       ├── _marts__models.yml
│       ├── dim_customers.sql        # table
│       ├── dim_products.sql         # table + contract + constraints
│       ├── dim_customer_segments_v1.sql
│       ├── dim_customer_segments_v2.sql
│       ├── dim_pii_customers.sql    # access: private, group: pii
│       ├── fct_orders.sql           # incremental delete+insert
│       ├── fct_order_items.sql      # incremental sync_all_columns, composite key
│       ├── fct_daily_sales.sql      # incremental
│       ├── fct_audit_events.sql     # incremental append
│       ├── fct_segment_activity.sql # consumes dim_customer_segments v=1
│       └── mv_recent_orders.sql     # Postgres materialized_view, manual REFRESH
├── snapshots/
│   ├── snp_customers_timestamp.sql
│   ├── snp_products_check.sql
│   └── snp_products_check_all.sql
├── tests/
│   ├── assert_no_future_orders.sql
│   ├── assert_fct_orders_amount_matches_items.sql
│   └── generic/
│       └── test_value_in_range.sql
├── macros/
│   ├── audit_columns.sql            # returns run_started_at + target.name
│   ├── cents_to_dollars.sql
│   ├── limit_data_in_dev.sql        # branches on target.name
│   ├── date_trunc_day.sql           # dispatch: default__ + postgres__
│   ├── get_custom_schema.sql        # generate_schema_name override
│   ├── grant_select.sql             # run-operation target
│   └── dbtae_companion__generate_surrogate_key.sql  # dispatch override of dbt_utils
├── analyses/
│   └── compare_fct_orders_versions.sql      # audit_helper demo
├── exercises/                       # broken examples — whole tree excluded via .dbtignore
│   ├── README.md                    # catalogue + trigger recipes
│   ├── cyclic/
│   ├── ref_typo/
│   ├── ref_disabled/
│   ├── ref_bad_version/
│   ├── contract_drift/
│   ├── access_violation/
│   ├── public_ephemeral/
│   ├── macro_undefined/
│   ├── macro_arity/
│   ├── dispatch_miss/
│   ├── jinja_unbalanced/
│   └── yaml/                        # *.yml.broken (manual rename to trigger)
├── scripts/
│   ├── save-baseline.sh             # cp -r target/ prior-artifacts/
│   ├── slim-ci.sh                   # canonical state:modified+ --defer recipe
│   ├── clone-demo.sh                # dbt clone against prior-artifacts
│   ├── mutate-customers.sql         # psql script for snapshot demo
│   └── rotate_loaded_at.sql         # psql script for source_status:fresher+ demo
└── prior-artifacts/                 # created by save-baseline.sh; gitignored
```

---

## Design notes

1. **Broken examples strategy.** The whole `exercises/` tree is excluded via `.dbtignore`. Reader copies the broken file into `models/_tmp_broken/` (or renames a YAML `.broken` file in place and temporarily drops `exercises/` from `.dbtignore`) to trigger. `enabled: false` would not protect the project from parse-fatal files (cyclic refs, Jinja/YAML syntax, access validation), which is why this repo uses `.dbtignore` rather than a gating var. See `exercises/README.md` for the flow.
2. **State demos.** Don't commit `prior-artifacts/` (noisy binaries, stale on every change). Ship `scripts/save-baseline.sh` and a README two-step recipe instead.
3. **Synthetic data.** Generate once, commit CSVs. Keep `scripts/generate_data.py` (stdlib only, with a fixed random seed) for reproducibility; CSVs are the committed source of truth.
4. **Mutable snapshot fixture.** `customers.csv` row #7 has its `email` bumped by `scripts/mutate-customers.sql`, run between two `dbt snapshot` invocations. This gives the reader observable SCD2 history without a complex demo harness.
5. **Incremental strategy defaulting.** Repo demonstrates `delete+insert` (on `fct_orders`), `merge` (on `fct_order_items`, dbt-postgres 1.8 native MERGE), and `append` (on `fct_audit_events`). README notes that `insert_overwrite` is partition-aware-adapter territory (BQ/Spark) and book reading only.
6. **Profiles strategy.** `profiles.yml.example` in repo; `.devcontainer/Dockerfile` copies it to `~/.dbt/profiles.yml` with env-var-substituted values (consumed by `postgres` output). Repo stays credential-free.
7. **Postgres role demo gotcha.** `db-init/01-roles.sql` must create roles before any GRANT runs. dbt `post_hook` grants run after DDL in the same transaction, so the roles must exist when `docker compose up` finishes — guaranteed by the init-scripts contract (they run once before Postgres accepts outside connections).
8. **Version pin strictness.** `requirements.txt` uses `==1.8.9` for `dbt-core` and `==1.8.2` for `dbt-postgres` (last stable 1.8 patches as of mid-2025). README "Stack & version notes" section cites dbt's migration guide URLs for when readers want to upgrade.
