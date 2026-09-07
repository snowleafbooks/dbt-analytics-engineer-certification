# Hard-coded relation — the edge that was never created

**Trigger:** `dbt run --select orders_hardcoded` · **exit 1** · **layer: run**

Two models. `hc_upstream` is ordinary and correct. `orders_hardcoded` reads from it by name:

```sql
select * from {{ target.schema }}.hc_upstream
```

Interpolating `target.schema` is what makes this survive review — it resolves to `dev` in dev
and `ci` in CI, so it *looks* environment-aware. It is still string interpolation. dbt only
learns about a dependency when `ref()` **runs**, and no `ref()` ran here.

**Expected error**

```
Database Error in model orders_hardcoded (models/_tmp_broken/orders_hardcoded.sql)
  relation "dev.hc_upstream" does not exist
  LINE 12: select * from dev.hc_upstream
```

dbt was asked to build `orders_hardcoded` and did exactly that, in a graph where it has no
parents, so `hc_upstream` was never built and the query has nothing to read.

**Fix:** `{{ ref('hc_upstream') }}`.

**The point, and the reason the suite asserts the manifest rather than this error.** The error
above is a *symptom*, and it is the lucky case. On a schema where somebody built `hc_upstream`
earlier — yesterday's run, another developer's session — the relation exists and this model
builds green, in whatever order the scheduler felt like, reading whatever was left behind. The
defect does not go away; the evidence does. So ask the graph, not the console:

```
$ dbt parse
$ python -c "import json; print(json.load(open('target/manifest.json'))['nodes']['model.dbtae_companion.orders_hardcoded']['depends_on']['nodes'])"
[]
```

An empty `depends_on.nodes` on a model that visibly reads from a project table is the whole
diagnosis, and it is true whether or not the build happened to pass.

**And it applies to every clause, not just the `FROM`.** A `ref()` in the `FROM` beside a
hard-coded name in a `JOIN` leaves the join's parent exactly this invisible, while the model
shows one honest edge in the lineage graph — which is more misleading than showing none.

`source()` is not the fix either: `source()` builds an edge to a *source*, which dbt does not
build. Between two models the answer is always `ref()`.

**Related:** `depends_on_comment` is the escape hatch for the case where the relation genuinely
cannot be a `ref()` in the query text.
