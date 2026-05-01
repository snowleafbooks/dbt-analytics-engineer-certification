# Dispatch miss — no default_\_ fallback

**Error layer:** compile
**Setup:** copy both `dispatch_miss.sql` (to `models/_tmp_broken/`) and `_macro.sql` (to `macros/_tmp/`).
**Fix:** add a `default__i_am_not_implemented` variant, OR a `postgres__i_am_not_implemented` variant. The `default__` version acts as the catch-all when the current adapter has no specific variant.
