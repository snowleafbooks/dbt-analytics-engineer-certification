# Dispatch miss — no `default__` fallback

**Trigger:** `dbt parse` · **exit 2** · **layer: parse**

`dbt compile --select dispatch_miss` reproduces it too; `dbt parse` alone is enough.

**Setup:** this case has a `macros/` sub-directory. `dispatch_miss.sql` goes to
`models/_tmp_broken/`; `macros/i_am_not_implemented.sql` goes to `macros/_tmp_broken/`.
The suite and the flow in `exercises/README.md` both handle that.

**Expected error**

```
Compilation Error
  In dispatch: No macro named 'i_am_not_implemented' found within namespace: 'None'
      Searched for: 'postgres__i_am_not_implemented', 'default__i_am_not_implemented'
```

**Fix:** add either `default__i_am_not_implemented` (catch-all for every adapter) or
`postgres__i_am_not_implemented` (this adapter only). The macro ships a `snowflake__`
variant and nothing else, so on Postgres the search falls through.

**The point:** read the *second* line, not the headline. The headline names the bare macro,
which exists; the `Searched for:` line names the two identifiers dispatch actually looked up,
and neither is the name you wrote. `adapter.dispatch('x')` never resolves to a macro
literally called `x` — it resolves to `<adapter>__x`, then `default__x`. A `default__`
variant is what stops a project being adapter-locked.
