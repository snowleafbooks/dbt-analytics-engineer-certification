# Cyclic ref()

**Error layer:** parse
**Fix:** break the cycle — e.g., extract the shared CTE into a third model both A and B can ref.

Copy both `A.sql` and `B.sql` into `models/_tmp_broken/`, comment `exercises/` out of `.dbtignore`, then:

```
dbt compile
```

(`dbt parse` alone does *not* flag cycles — the cycle-detection check fires during topological sort, which only happens when dbt needs an execution order.)

Expected:
```
Found a cycle: model.dbtae_companion.A --> model.dbtae_companion.B --> model.dbtae_companion.A
```
