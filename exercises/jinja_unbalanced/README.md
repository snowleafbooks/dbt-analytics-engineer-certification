# Unbalanced Jinja block

**Error layer:** parse (Jinja templating).
**Fix:** add the missing `{% endif %}` after the if-branch.

This is the kind of error that fires before any SQL is compiled — useful as a mental bookmark that Jinja is "layer 0" in triage.
