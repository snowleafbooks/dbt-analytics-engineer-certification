# `access: private` cross-group `ref()`

**Trigger:** `dbt parse` · **exit 2** · **layer: parse**

The consumer declares `group='marketing'`; `dim_pii_customers` is `access: private` inside
group `pii`.

**Expected error**

```
Parsing Error
  Node model.dbtae_companion.cross_group_consumer attempted to reference node model.dbtae_companion.dim_pii_customers, which is not allowed because the referenced node is private to the 'pii' group.
```

**Fix:** one of —

- move the consumer into group `pii` (right answer when the consumer genuinely handles
  data-subject data),
- relax the producer to `access: protected` (wrong for PII),
- publish a masked view in group `marketing` and `ref()` that instead.

**The point:** governance is enforced by the parser, not by the warehouse. The build fails
before any SQL compiles and before any DDL runs, so an invalid reference is caught in the
pull request that introduced it. That is the opposite end of the spectrum from `grants:`,
which is a warehouse privilege and only bites the person running the query.
