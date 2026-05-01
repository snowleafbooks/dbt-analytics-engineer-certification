# access: public + materialized: ephemeral

**Error layer:** parse
**Fix:** change `materialized` to `view` or `table`. A public model must have a warehouse identity for downstream refs to resolve.
