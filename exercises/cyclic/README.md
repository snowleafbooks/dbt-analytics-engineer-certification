# Cyclic `ref()`

**Trigger:** `dbt compile` · **exit 2** · **layer: compile**

`A` refs `B`, `B` refs `A`. `dbt parse` on this fixture exits **0** — the manifest builds
fine, because a cycle is a property of the *graph*, not of any one node. The cycle is only
found when dbt links the graph to work out an execution order, which is the first thing
`compile` / `run` / `build` / `test` do and the one thing `parse` never does.

**Expected error**

```
Encountered an error:
Found a cycle: model.dbtae_companion.A --> model.dbtae_companion.B
```

dbt then prints a Python traceback ending in
`RuntimeError: Found a cycle: model.dbtae_companion.A --> model.dbtae_companion.B`,
raised while linking the graph. The message names the two nodes on the cycle but does not
close the loop back to `A` — read it as "A depends on B, and B gets you back to A".

**Fix:** break the cycle. Usually that means extracting the logic both models share into a
third model that each of them can `ref()` one-way.

**The point:** a green `dbt parse` does not mean a runnable project. Parse validates files;
linking validates the graph.
