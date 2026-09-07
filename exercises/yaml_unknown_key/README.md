# Unknown property — the silent one

**Trigger:** `dbt parse` · **exit 0** · **no error, on this adapter**

**This case has no error output. That is the exercise.** `frobulate: enthusiastically` is not
a dbt property. On Postgres, `dbt parse` accepts the file, exits 0, prints nothing, and the
key never reaches the manifest:

```
$ dbt parse
...
Performance info: target/perf_info.json
$ echo $?
0
```

```python
>>> import json; m = json.load(open('target/manifest.json'))
>>> 'frobulate' in m['nodes']['model.dbtae_companion.unknown_key_model']
False
```

There is nothing here for `--warn-error` to escalate either: escalation promotes warnings dbt
has already emitted, and it emits none about `frobulate`. Do not test that with a bare
`dbt parse --warn-error`, though — this project carries an unrelated deprecation on purpose
(`fct_segment_activity` refs `dim_customer_segments.v1`, which has a `deprecation_date`), and
`--warn-error` turns *that* warning into a `Compilation Error` and exit 2, which says nothing
about this fixture. Silence the one you are not asking about:

```bash
dbt parse --warn-error-options '{"error": "all", "silence": ["UpcomingReferenceDeprecation"]}'
# exit 0 -- at the strictest setting dbt has, still not one word about frobulate
```

The suite asserts exactly this: exit 0, no diagnostic, and the key absent from the manifest.

## Why nothing is emitted here

dbt's YAML jsonschema validation — the check that produces the `Custom key ... found in ...`
deprecation warning for an unrecognised property — runs only on a set of supported adapters.
The gate is in the installed package, `dbt/jsonschemas/jsonschemas.py`:

```python
_JSONSCHEMA_SUPPORTED_ADAPTERS = {
    "bigquery",
    "databricks",
    "redshift",
    "snowflake",
}

def _can_run_validations() -> bool:
    invocation_context = get_invocation_context()
    return invocation_context.adapter_types.issubset(_JSONSCHEMA_SUPPORTED_ADAPTERS)
```

`postgres` is not in the set, so validation returns early and the whole family of unknown-key
deprecations is skipped. On one of the four listed adapters the same file produces a warning
naming `frobulate` and the file it was found in — and `--warn-error` there turns that warning
into a failed build. Nothing about the YAML changes; only the adapter does.

## The lesson, which is not about `frobulate`

A misspelled property is not an error you wait for. It is a config that appears to be set and
is not:

- `materialised:` instead of `materialized:` — the model stays a view and nothing says so.
- a `+` misplaced in `dbt_project.yml` — grants replace instead of merge.
- `tests:` where `data_tests:` was meant — the tests never run, and a green build means
  nothing ran rather than everything passed.

So when a config "isn't taking effect", do not read the log for a warning that may never
come. Read the artifact:

```bash
dbt parse
python -c "import json;print(json.load(open('target/manifest.json'))['nodes']['model.dbtae_companion.fct_orders']['config'])"
```

The manifest is what dbt actually believes. `dbt ls --output json --output-keys name config`
answers the same question for many nodes at once. If a key is not in there, dbt is not
applying it, whether or not anything was printed.

**Related:** `yaml_wrong_type` is the mirror image — a property dbt *does* know, given a value
of the wrong type, which fails loudly at parse. Known key, bad value: loud. Unknown key: on
this adapter, silent.
