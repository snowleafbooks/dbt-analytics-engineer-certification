# `-- depends_on:` — a comment that is not a comment yet

**Trigger:** `dbt parse` · **exit 0** · **no error, and that is the exercise**

Three models. `dc_upstream` is the parent. The other two read from it by hard-coded name, and
differ by one character of comment syntax:

| File | Line 1 | Edge recorded |
|---|---|---|
| `orders_via_sql_comment.sql` | `-- depends_on: {{ ref('dc_upstream') }}` | **yes** |
| `orders_via_jinja_comment.sql` | `{# depends_on: {{ ref('dc_upstream') }} #}` | **no** |

```
$ dbt parse
$ python -c "import json; m=json.load(open('target/manifest.json'));
  print([n['depends_on']['nodes'] for k,n in m['nodes'].items() if 'orders_via' in k])"
[['model.dbtae_companion.dc_upstream'], []]
```

## Why the SQL comment works

dbt renders every model as a **Jinja template first**, and only hands the result to the
warehouse as SQL. On line 1 of `orders_via_sql_comment.sql`, `{{ ref('dc_upstream') }}` is
therefore live Jinja: it executes, registers the dependency, and returns the relation name. The
leading `--` means nothing at all at that moment. It starts mattering one step later, when the
rendered text reaches the SQL parser and the whole line is discarded as a comment.

So the edge is real and the compiled query is byte-for-byte what it would have been anyway.
That is the entire trick: a dependency with no effect on the SQL.

`{# ... #}` is a **Jinja** comment. Jinja removes the block during rendering without evaluating
what is inside it, so the `ref()` never runs, and a file that is one character different from
its neighbour does nothing whatsoever.

## When to reach for it

Rarely, and always because the relation cannot appear as a `ref()` in the query text:

- a macro assembles the relation name at run time (`dbt_utils.union_relations`, a dynamic
  `{% for %}` over relations),
- a `pre_hook` / `post_hook` touches a table the model body never names,
- an incremental branch reads a model only on the `is_incremental()` path — see
  `conditional_ref` for why that branch's `ref()` may not be recorded at all.

It is not a licence to hard-code relations. If the name can be a `ref()`, make it one; see
`hardcoded_relation`.

**Related:** `hardcoded_relation` is the defect this repairs; `conditional_ref` is the case
where the `ref()` is written and still does not count.
