# Macro called with wrong kwarg

**Error layer:** compile
**Fix:** `precision_level=4` → `precision=4`. The macro signature in [macros/cents_to_dollars.sql](../../macros/cents_to_dollars.sql) is authoritative.
