# `merge` with no `unique_key`

**Trigger:** `dbt run` (twice) · **exit 0** · **layer: run** · **no error, no warning**

**Expected behaviour — there is no error message to read**

```
Done. PASS=1 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=1
```

The diagnosis is only in the compiled SQL:

```sql
merge into "dbtae"."dev"."merge_no_unique_key" as DBT_INTERNAL_DEST
    on (FALSE)
when not matched then insert
```

`on (FALSE)` means no existing row can ever match, and there is **no `when matched` branch at
all**. The merge has silently become an append.

**Fix:** add `unique_key='id'` to the config. The predicate becomes
`on (DBT_INTERNAL_SOURCE.id = DBT_INTERNAL_DEST.id)` and a `when matched then update set`
branch appears.

**The point:** every other exercise in this folder is diagnosed by reading an error. This one
has no error to read. `merge` needs a key to match on; without one dbt does not refuse, it
degrades — so the table gains a duplicate of every incoming row on each run and the console
says `PASS`. When a strategy's precondition is missing and dbt stays quiet, the compiled SQL
under `target/` is the only place the truth is written down.

Compare `ref_typo`, where the error names the fault in its own text. Silence is the harder
failure, and it is the one that reaches production.
