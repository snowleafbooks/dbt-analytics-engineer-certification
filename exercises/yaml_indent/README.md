# YAML indentation error

**Trigger:** `dbt parse` · **exit 2** · **layer: parse (YAML load)**

`columns:` is indented three spaces where the sequence item needs four, so it reads as a
sibling of the list rather than a key inside the mapping that `- name: fct_orders` opened.

**Expected error**

```
Parsing Error
  Error reading dbtae_companion: _tmp_broken/_indent.yml - Runtime Error
    Syntax error near line 5
    ------------------------------
    2  |
    3  | models:
    4  |   - name: fct_orders
    5  |    columns:
    6  |       - name: order_id
    7  |         data_tests:
    8  |           - unique

    Raw Error:
    ------------------------------
    while parsing a block collection
      in "<unicode string>", line 4, column 3
    did not find expected '-' indicator
      in "<unicode string>", line 5, column 4
```

**Fix:** indent `columns:` to four spaces, level with `name:`.

**The point:** this is the earliest failure in the whole catalogue — the file never becomes a
data structure, so dbt has no model, no config and no name to complain about. Read the **Raw
Error** block, not the dbt wrapper: it gives two coordinates, where the structure *started*
(line 4, column 3) and where it broke (line 5, column 4), and the fix is always at the second
one relative to the first. This is also the only YAML case where the error names a line
number, which is why it is the easiest of the three.
