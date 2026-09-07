# Dev container, and the verification suite

## The container

`devcontainer.json` + `docker-compose.yml` stand up two services: a Python image with dbt
installed (`Dockerfile`) and Postgres 15 seeded by `db-init/`. *Reopen in Container* runs
`post-create.sh` (copies `profiles.yml.example` into `~/.dbt`, installs `requirements.txt`,
`dbt deps`, `dbt debug`) and then `post-start.sh` on every start (waits for Postgres).

## The verification suite — the `_*.sh` scripts

These are checks, not setup. Each one asserts a behaviour the book describes, prints what it
found, and exits non-zero if the claim no longer holds. They exist so that a dbt upgrade, an
adapter change or a data regeneration cannot quietly invalidate a chapter: run them, and the
repo tells you which claim broke.

Run them after `dbt build`, from the repo root or anywhere:

```bash
bash .devcontainer/_test_exercises.sh      # all twenty-two triage fixtures
bash .devcontainer/_check_grants.sh        # grants: replace vs. additive semantics
bash .devcontainer/_clone_test.sh          # dbt clone --state, and the Postgres view fallback
bash .devcontainer/_mv_verify.sh           # materialized view: kind, populated, REFRESH
bash .devcontainer/_verify_identifier.sh   # source identifier: aliasing, end to end
bash .devcontainer/_verify_disabled.sh     # enabled: false -- parsed, then parked
```

| Script | Asserts |
|---|---|
| `_test_exercises.sh` | Every fixture in `exercises/` still has its documented outcome: error cases assert exit code, failing layer (parse / compile / run) and a regex from dbt's own message; silent and artifact cases assert their stated artifact. Checks first that the *clean* project parses, so a forgotten `dbt deps` is reported as a missing package rather than as twenty-two fixture failures. Accepts case names as arguments to run a subset. |
| `_check_grants.sh` | `grants={'select': [...]}` **replaces** the project default (`fct_orders` → `bi_reader` only); `grants={'+select': [...]}` **merges** with it (`fct_order_items` → `analytics_reader` *and* `finance_reader`). |
| `_clone_test.sh` | `dbt clone --state ./prior-artifacts` succeeds against the baseline manifest, and the clones land as **views** — Postgres has no zero-copy clone, so dbt falls back rather than copying. |
| `_mv_verify.sh` | `mv_recent_orders` is a real materialized view (in `pg_matviews`, not `pg_views`/`pg_tables`), is populated, and `REFRESH MATERIALIZED VIEW` brings the stored copy back into agreement with the model's 7-day window — which is non-empty. It deliberately does **not** assert that the row count is unchanged by the refresh: the window slides daily, so a matview built yesterday *should* change. |
| `_verify_identifier.sh` | `source('raw_ecom','product_catalog')` compiles to `raw_ecom.products` via `identifier:`, and no row is lost through the staging model. |
| `_verify_disabled.sh` | `_example_disabled` is absent from `dbt ls` but present in `manifest['disabled']` — parsed, then parked. Also shows that `dbt ls --select` gives an identical answer for a disabled node and a name that never existed, which is why the manifest is the only tell. It gates on `dbt parse` first and on `dbt ls` returning a non-empty DAG, because "absent" and "the manifest says so" are both vacuously satisfiable by a dbt that cannot run at all. |

`_runner.sh` is not a check: it is a wrapper that puts `profiles.yml` in place and then execs
whatever you pass it (`bash .devcontainer/_runner.sh dbt build`). It never overwrites a
`profiles.yml` that is already there — that file belongs to whatever project put it there — so
if yours has no `dbtae_companion:` profile it warns and leaves it, rather than doing nothing and
letting every dbt call fail with `Could not find profile named 'dbtae_companion'`.

## Running them outside the container

Every script resolves the repo root from its own location and reads connection details from
the environment, so a local clone works the same. Overrides:

| Variable | Default | Use |
|---|---|---|
| `DBT` | `dbt` | path to the dbt executable (e.g. a virtualenv) |
| `PYTHON` | `python` | interpreter for the manifest probes |
| `DBT_PROFILES_DIR` | `$HOME/.dbt` | where `profiles.yml` lives |
| `DBT_TARGET` | profile default | target for `_test_exercises.sh` |
| `DBT_SCHEMA` | `dev` | schema the warehouse assertions read |
| `POSTGRES_HOST` / `_PORT` / `_USER` / `_DB` / `_PASSWORD` | `postgres` / `5432` / `dbt_developer` / `dbtae` / `dbt_developer_pw` | connection |
| `PSQL` | `psql -h $POSTGRES_HOST -p $POSTGRES_PORT` | the whole psql command prefix, for when the client only exists inside the container: `PSQL='docker exec -i devcontainer-postgres-1 psql'` |

## Warehouse side effects

`_clone_test.sh` drops and recreates `ci.fct_orders` and `ci.fct_order_items`, and **names
anything that goes with them** — `ci.mv_recent_orders` is built on the clones, so a `cascade` takes
it too. The script prints the dependent list before it drops, and uses `RESTRICT` when there is
none; put a dependent back with `dbt build --target ci`. `_mv_verify.sh` refreshes
`dev.mv_recent_orders`.

Anything these leave behind, and anything an afternoon of practice leaves behind, comes back out
with `bash scripts/reset-warehouse.sh` — it reloads the raw schemas from `data-seed/*.csv` and
drops the schemas `dbt ls` says this project writes to. It is the only route back from a source
`UPDATE` or from accumulated snapshot history, because `db-init/` runs only on an empty data
directory and does not replay on a container restart.

`_test_exercises.sh` stages into `models/_tmp_broken/` and `macros/_tmp_broken/` and removes both
on exit — the `EXIT` trap is joined by explicit `INT` and `TERM` traps, so Ctrl-C leaves nothing
staged either. Twenty-one of its twenty-two cases fail before or during DDL and write nothing to
the warehouse. **`merge_no_unique_key` is the exception and has to be**: its lesson is a silent
degradation that only appears on the *second* incremental run, so the case builds one relation in
the target schema. It is selected on its own (`--select merge_no_unique_key`, not a whole-project
`dbt run`) and dropped again when the case ends; if no `psql` is reachable the script says so
rather than pretending it cleaned up.

Three of them write `target/` as a side effect, which is ordinary build output and never
committed: `_test_exercises.sh` and `_verify_disabled.sh` both run `dbt parse`, and
`_clone_test.sh` leaves a `run_results.json` behind because `dbt clone` writes one like any other
command. `_verify_identifier.sh` used to be a fourth; it now compiles into a temporary
`--target-path` on every run, both so it cannot pass on a stale artifact and so it cannot clobber
the `run_results.json` that the `result:` and `--state` demos read. `_runner.sh` writes
`profiles.yml` into `$DBT_PROFILES_DIR` (`~/.dbt` by default) if that file does not exist.
