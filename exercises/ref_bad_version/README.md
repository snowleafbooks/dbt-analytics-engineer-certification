# ref() with invalid version

**Error layer:** parse
**Fix:** `v=99` → `v=1` or `v=2` (the two versions declared in `dim_customer_segments.yml`). Or omit `v=` entirely to use `latest_version`.
