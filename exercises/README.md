# Triage exercises

Twenty-two deliberately-broken cases, one per sub-directory. Most fail for exactly one reason
at exactly one layer, and their READMEs quote the error dbt actually emits — captured from a
real run, not paraphrased. Five of them fail nothing, or fail somewhere the console never
mentions; those are the ones worth your time, and they are marked in the catalogue below.

Nothing in here is part of the project. `exercises/` sits outside every `*-paths` entry in
`dbt_project.yml` (`model-paths`, `macro-paths`, `seed-paths`, `snapshot-paths`,
`analysis-paths`, `test-paths`), so dbt never walks this tree and `dbt build` stays green with
every one of these fixtures sitting in the repo. A fixture only becomes real when you copy it
into `models/`.

## How to trigger an exercise — one flow, every case

```bash
CASE=ref_typo                     # any sub-directory name

mkdir -p models/_tmp_broken
find "exercises/$CASE" -maxdepth 1 -type f ! -name README.md \
     -exec cp {} models/_tmp_broken/ \;

# only dispatch_miss has this: a macros/ sub-directory
[ -d "exercises/$CASE/macros" ] && mkdir -p macros/_tmp_broken \
    && cp "exercises/$CASE/macros/"*.sql macros/_tmp_broken/

# then the trigger command from the case README, e.g.
dbt parse

rm -rf models/_tmp_broken macros/_tmp_broken
```

That is the whole procedure, and it is identical for every case — copy the files in, run one
command, read the result, delete the directory. Some cases stage more than one file, and
`conditional_ref` and `test_config_not_nested` are run twice with different flags; the case
README says so. `.devcontainer/_test_exercises.sh` runs exactly these steps for every case and
asserts the result, so the suite and this page cannot drift.

Two things that do **not** work, and are worth knowing why:

- **Renaming a file inside `exercises/` does not arm it.** dbt discovers files by walking the
  configured `*-paths`, and `exercises/` is not under any of them. A `.sql` file sitting right
  here is invisible no matter what it is called. The file has to move.
- **Editing `.dbtignore` changes nothing here.** `.dbtignore` filters the files dbt finds while
  walking those paths. It cannot un-hide a tree dbt never walks. (The `exercises/` line in
  `.dbtignore` is a second guard that would start mattering the day someone widens
  `model-paths` — see the note at the bottom.)

Do not leave `models/_tmp_broken/` behind. It is not in `.gitignore`, so a fixture abandoned
mid-exercise shows up as untracked junk and, worse, as a broken node in the next `dbt build`.

## Catalogue

Exit code and layer are as observed, and the suite asserts both. Exit **2** is dbt failing the
command; exit **1** is the command succeeding with a failed node inside it.

| Case | Trigger | Exit | Layer | The error, in one line |
|---|---|---|---|---|
| `yaml_indent/` | `dbt parse` | 2 | parse (YAML load) | `did not find expected '-' indicator` — the file never becomes a data structure |
| `yaml_wrong_type/` | `dbt parse` | 2 | parse | `at path ['materialized']: True is not of type 'string'` |
| `yaml_unknown_key/` | `dbt parse` | **0** | — | **nothing.** An unknown property is accepted silently on this adapter; the key never reaches the manifest |
| `test_config_not_nested/` | `dbt parse` | **0** | — | a `severity:` written beside the test name instead of under `config:`. `PropertyMovedToConfigDeprecation`, and it still applies — until `--warn-error-options` makes it exit 2 |
| `jinja_unbalanced/` | `dbt parse` | 2 | parse (Jinja) | `Unexpected end of template. Jinja was looking for ... 'endif'` |
| `ref_typo/` | `dbt parse` | 2 | parse | `depends on a node named 'stg_orderz' which was not found` |
| `ref_disabled/` | `dbt parse` | 2 | parse | `depends on a node named 'disabled_target' which is disabled` |
| `ref_bad_version/` | `dbt parse` | 2 | parse | `depends on a node named 'dim_customer_segments' with version '99' which was not found` |
| `access_violation/` | `dbt parse` | 2 | parse | `not allowed because the referenced node is private to the 'pii' group` |
| `public_ephemeral/` | `dbt parse` | 2 | parse | `with 'ephemeral' materialization has an invalid value (public) for the access field` |
| `macro_arity/` | `dbt parse` | 2 | parse | `macro 'dbt_macro__cents_to_dollars' takes no keyword argument 'precision_level'` |
| `dispatch_miss/` | `dbt parse` | 2 | parse | `In dispatch: No macro named 'i_am_not_implemented' found within namespace: 'None'` |
| `cyclic/` | `dbt compile` | 2 | compile (graph link) | `Found a cycle: model.dbtae_companion.A --> model.dbtae_companion.B` |
| `macro_undefined/` | `dbt compile --select macro_undefined` | 2 | compile | `'generate_surrogate_key' is undefined` |
| `contract_drift/` | `dbt run --select contract_drift` | 1 | run | `This model has an enforced contract that failed` + a mismatch table |
| `constraint_missing_data_type/` | `dbt run --select constraint_missing_data_type` | 1 | run | `Contracted models require data_type to be defined for each column` |
| `source_misresolved/` | `dbt run --select stg_orders_misresolved` | 1 | run | `relation "ecom_landing.orders" does not exist` |
| `unquoted_macro_arg/` | `dbt run --select unquoted_macro_arg` | 1 | run | `syntax error at or near "as"` — the compiled SQL reads `cast( as numeric)`, because an unquoted argument is a Jinja variable |
| `hardcoded_relation/` | `dbt run --select orders_hardcoded` | 1 | run | `relation "dev.hc_upstream" does not exist` — and the real evidence is `depends_on.nodes == []` |
| `depends_on_comment/` | `dbt parse` | **0** | — | **nothing.** `-- depends_on:` registers the edge, `{# depends_on: #}` does not; one character apart |
| `conditional_ref/` | `dbt parse`, twice | **0** | — | **nothing.** Same file, two parents, depending on the `--vars` it was parsed with |

The table is ordered by layer, and the ordering is the drill. Triage is a binary search over
these layers, and each command clears everything above it:

- **`dbt parse` clean** → YAML loads, Jinja renders, every `ref()`/`source()`/`group`
  resolves. Ten cases are already excluded.
- **`dbt compile` clean** → the graph links (no cycles) and every macro call actually
  executes. Two more excluded.
- **Still broken** → it is warehouse-shaped: a contract, a constraint, a relation that is not
  where the YAML says it is. Now the compiled SQL in `target/` is the artifact to read.

And then the part the binary search cannot reach. **Five cases clear every layer**, because
nothing is broken in a way a command reports: `yaml_unknown_key`, `depends_on_comment`,
`conditional_ref`, `test_config_not_nested`, and the half of `hardcoded_relation` that matters.
For those the artifact *is* the diagnosis — `depends_on.nodes` in `target/manifest.json`, or a
config that never arrived:

```bash
dbt parse
dbt ls --select <model> --output json --output-keys name config depends_on
```

A green command is not evidence that dbt did what the file appears to say. It is evidence that
dbt found nothing to complain about, which is a much weaker statement, and the five cases above
are what the difference costs.

Several cases are placed deliberately next to each other, because each group looks like one
lesson and is two:

- `macro_undefined` vs `macro_arity` vs `unquoted_macro_arg` — three "macro errors" at three
  layers. An unknown *name* survives parse and dies at compile; a known macro given a bad
  *keyword* dies at parse; a known macro given an unquoted *positional* argument sails through
  both and dies in the warehouse, because an undefined Jinja name is not an error, it is the
  empty string.
- `contract_drift` vs `constraint_missing_data_type` — both contract failures at run. One is a
  mismatch between two stated shapes; the other is a shape that was never fully stated.
- `yaml_wrong_type` vs `yaml_unknown_key` vs `test_config_not_nested` — known key with a bad
  value fails loudly; an unknown key on a *model* says nothing at all on this adapter; a
  misplaced config on a *test* warns on every adapter and still applies. How much checking you
  get depends on which object and which adapter, not on how wrong you were.
- `hardcoded_relation` vs `depends_on_comment` vs `conditional_ref` — three ways to end up with
  a DAG that does not match the SQL. No `ref()` at all; a `ref()` in the one comment syntax that
  works and the one that does not; and a `ref()` that is written, valid, and still never runs.
  All three exit 0 at parse. None of them is visible in a log.

## Why the tree is gated by location rather than `enabled: false`

`enabled: false` is applied *after* parse. Ten of these cases are parse-fatal — YAML that
will not load, Jinja that will not render, a `ref()` that cannot resolve — so dbt would fail
before it ever read the config that was supposed to protect it. There is no config you can put
inside a broken file that stops the file from breaking the project.

Living outside every configured `*-path` is the guard that works, because it means dbt never
opens the file. `.dbtignore` is kept as a second line of defence: it does nothing today, and
it would matter the moment `model-paths` grew to include this tree.
