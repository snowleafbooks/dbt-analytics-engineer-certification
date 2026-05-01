# Undefined macro (missing namespace)

**Error layer:** compile
**Fix:** prefix with the package: `{{ dbt_utils.generate_surrogate_key(['customer_id']) }}`.
