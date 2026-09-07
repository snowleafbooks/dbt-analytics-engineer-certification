{% docs pii_email %}
The customer's primary email address.

**Classification:** PII. Treat as restricted — do not expose in downstream dashboards without masking.
Values are lowercased upstream and are unique at the account level.
{% enddocs %}

{% docs order_status %}
The current lifecycle state of an order. Transitions:

- `pending` → `paid` → `shipped` → `delivered`
- `pending` → `cancelled`
- any state → `refunded` (after `delivered`)

Downstream facts should preserve this exact vocabulary.
{% enddocs %}

{% docs surrogate_key_convention %}
Surrogate keys are md5 hex digests generated via `dbt_utils.generate_surrogate_key`,
resolved through this project's dispatch override in `macros/generate_surrogate_key.sql`.

The override is a drop-in replacement whose behavioural difference is *normalisation*,
not the hash primitive: every field is lower-cased and trimmed before hashing, so casing or
whitespace drift at source does not produce a new key. The primitive remains `md5`, emitted
directly as a literal `md5(...)` call. It is the `dbt_utils` default implementation that
reaches the primitive through `dbt.hash()`; this override does not.

The override wins because it is named `default__generate_surrogate_key`, which is one of the
two names `adapter.dispatch` searches for. A macro named after the package
(`dbtae_companion__generate_surrogate_key`) would never be found.
{% enddocs %}
