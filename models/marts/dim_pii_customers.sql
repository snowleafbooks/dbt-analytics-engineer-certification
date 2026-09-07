{# Access-restricted: private + group pii. Cross-group refs will parse-fail.

   `grants={'select': []}` IS NOT THE SAME AS OMITTING THE CONFIG. dbt_project.yml grants
   `select` on the whole `marts` folder to `analytics_reader`. An empty list is a model-level
   `select:` like any other, so REPLACE semantics apply: it replaces the inherited list with
   nothing, and dbt reconciles the relation to zero grantees. A PII table is the right place
   for it -- inheriting a folder-wide read grant is exactly what must not happen here.

     dbt run --select dim_pii_customers
     psql -c "\dp dev.dim_pii_customers"    # Access privileges column is EMPTY, while every
                                            # other mart in the folder shows analytics_reader
     bash .devcontainer/_check_grants.sh     # asserts it, alongside the replace and additive
                                            # cases on the other two marts

   WHAT `[]` DOES DEPENDS ON WHETHER THE RELATION SURVIVES THE RUN, and this model is the
   easy half. It is a `table`, dropped and recreated every build, so the new relation starts
   with no grantees and the empty list means dbt simply issues no `grant` -- grep the debug
   log and there is no `revoke` here, because there was nothing to revoke. On a relation that
   PERSISTS across runs -- an incremental model, a materialized view -- the same empty list
   makes dbt issue the statement for real. Watch it on the incremental one next door:

     psql -c "grant select on dev.fct_order_items to marketing_reader"
     dbt run --select fct_order_items       # dbt reconciles to the configured set
     grep -i revoke logs/dbt.log            # revoke SELECT on ... from "marketing_reader"

   The third state is the one people conflate `[]` with. DELETE the `grants` config entirely
   and dbt stops managing grants on that relation at all: whatever privileges are on it stay,
   with no log line saying so. One line of YAML apart, opposite outcomes.
#}
{{ config(
    materialized='table',
    access='private',
    group='pii',
    grants={'select': []},
    tags=['pii', 'pii_gdpr']
) }}

select
    customer_id,
    email,
    first_name || ' ' || last_name  as full_name,
    address_line_1,
    city,
    postal_code,
    country_code
from {{ ref('stg_customers') }}
