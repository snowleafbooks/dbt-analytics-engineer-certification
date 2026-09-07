# Test config that is not under `config:`

**Trigger:** `dbt parse` · **exit 0, with a deprecation** · then the same parse under
`--warn-error-options`, **exit 2**

`severity` is a test **config**. It belongs under a nested `config:` key:

```yaml
data_tests:
  - not_null:
      config:
        severity: warn
```

The fixture writes it as a bare sibling of the test name instead:

```yaml
data_tests:
  - not_null:
      severity: warn
```

**What dbt 1.11.14 actually does — measured, on Postgres**

```
$ dbt parse
[WARNING][PropertyMovedToConfigDeprecation]: Deprecated functionality
Found `severity` as a top-level property of `data_tests.not_null.severity` in
file `models/_tmp_broken/_test_config_not_nested.yml`. The `severity` top-level
property should be moved into the `config` of `data_tests.not_null.severity`.
$ echo $?
0
```

And it still takes effect — this is a deprecation, not a no-op:

```
$ dbt ls --select test_config_model --output json --output-keys name config
{"name": "not_null_test_config_model_order_id", "config": {…, "severity": "warn", …}}
```

So the honest statement is: **the misplaced key works today, warns every parse, and is one flag
away from being a hard build failure.** Promote just that deprecation and the same file stops
the command dead:

```
$ dbt parse --warn-error-options '{"error": ["PropertyMovedToConfigDeprecation"]}'
Encountered an error:
Compilation Error
  Invalid generic test configuration given in models/_tmp_broken/_test_config_not_nested.yml:
  [WARNING][PropertyMovedToConfigDeprecation]: Deprecated functionality
  Found `severity` as a top-level property of `data_tests.not_null.severity` …
$ echo $?
2
```

The suite asserts **both halves**. Asserting only the clean exit would record "dbt allows this",
which is the reassuring half of a fact whose other half fails a build.

## The rule this fixture is protecting

Under a generic test, the nested `config:` block is the only place dbt looks for
`severity`, `where`, `limit`, `store_failures`, `store_failures_as`, `error_if`, `warn_if`,
`enabled`, `tags` and `meta`. Anything else you write at that level is not a config at all — it
is an **argument to the test macro**. Misspell the key by one letter and you can watch that
happen:

```
$ # ... with `serverity: warn` (a typo) instead of `severity`
[WARNING][MissingArgumentsPropertyInGenericTestDeprecation]: Deprecated functionality
Found top-level arguments to test `not_null` defined on 'test_config_model' in
package 'dbtae_companion' (models/_tmp_broken/_test_config_not_nested.yml).
Arguments to generic tests should be nested under the `arguments` property.

Encountered an error:
Compilation Error in test not_null_test_config_model_order_id__warn (…_test_config_not_nested.yml)
  macro 'dbt_macro__test_not_null' takes no keyword argument 'serverity'
$ echo $?
2
```

Note the generated test name — `…_order_id__warn`. dbt appended the *value* of the stray key,
because it thinks `warn` is an argument. And note the error itself: it is word for word the
error in `macro_arity`, because it is the same error. A generic test **is** a macro call, and
anything you write beside the test name that dbt does not recognise as a config is handed to it
as a keyword argument.

So the two failure modes are not symmetrical, and it is worth knowing which one you have:

| What you wrote | dbt 1.11.14 | Does it apply? |
|---|---|---|
| `severity:` beside the test name | `PropertyMovedToConfigDeprecation`, **exit 0** | yes, for now |
| `serverity:` (a typo) beside it | `MissingArgumentsPropertyInGenericTestDeprecation` **and a Compilation Error, exit 2** | no |
| `severity:` under `config:` | nothing | yes |

The dangerous row is the first: the only one that ships.

## Why this sits next to `yaml_unknown_key`

`yaml_unknown_key` puts an unknown property on a **model** and dbt says nothing at all on this
adapter — its jsonschema validation runs only on BigQuery, Databricks, Redshift and Snowflake.
This case puts a misplaced property on a **test** and dbt complains on every adapter, because
the generic-test parser does the checking itself and is not adapter-gated.

Read the pair together, and the lesson is not "dbt validates YAML" or "dbt doesn't". It is that
the amount of checking you get depends on *which* object and *which* adapter — so the manifest,
not the log, is what tells you whether a config was applied. That is the `dbt ls --output-keys`
call above, and it is the only answer that does not depend on the warehouse you happen to be on.

**Related:** `yaml_unknown_key` (silent on this adapter), `yaml_wrong_type` (known key, wrong
type, loud at parse).
