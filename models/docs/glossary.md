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
Surrogate keys are sha256 hex digests generated via `dbt_utils.generate_surrogate_key`
with the project-level dispatch override (`dbtae_companion__generate_surrogate_key`).

The override is a drop-in replacement that pins the hash algorithm to `sha256` for
cross-adapter determinism.
{% enddocs %}
