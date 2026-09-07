# Unbalanced Jinja block

**Trigger:** `dbt parse` · **exit 2** · **layer: parse (Jinja)**

**Expected error**

```
Compilation Error in model jinja_unbalanced (models/_tmp_broken/jinja_unbalanced.sql)
  Unexpected end of template. Jinja was looking for the following tags: 'elif' or 'else' or 'endif'. The innermost block that needs to be closed is 'if'.
    line 7
      from {{ ref('stg_orders') }}
```

**Fix:** add the missing `{% endif %}` after the if-branch.

**The point:** Jinja is layer 0. Nothing about the SQL has been looked at — no `ref()`
resolution, no dbt config, no warehouse. Note also that the reported line (7) is where the
template *ran out*, not where the unclosed `{% if %}` is: with a block error the line number
is the end of the search, and the `innermost block that needs to be closed` clause is the
actual lead.
