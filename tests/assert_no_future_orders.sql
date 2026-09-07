{#
    Singular test: the orders mart contains no order that has not happened yet.

    Where this test points is the whole lesson. The raw feed legitimately carries
    scheduled and pre-ordered rows with a future `created_at`, and `stg_orders`
    deliberately keeps them — staging renames and recasts, it does not adjudicate.
    fct_orders applies the business rule (`created_at <= current_timestamp`), so this
    test belongs on the mart. Pointed at staging it would either fail forever or,
    worse, quietly pass because the fixture had aged out of the future — a test that
    decays into a false green.

    `dbt.current_timestamp()` matches the expression fct_orders filters on, so the two
    cannot drift. `dbt build` runs a test after the model it depends on, so the mart's
    cut-off is always at or before this test's — the comparison has no race.

    severity: error — a future-dated row in the mart means the business rule was lost.
    store_failures writes the offending rows to a table so they can be inspected
    (`dev_dbt_test__audit.assert_no_future_orders`), and `limit` caps how many land there.
#}
{{ config(
    severity='error',
    store_failures=true,
    store_failures_as='table',
    limit=500,
    tags=['critical']
) }}

select
    order_id,
    customer_id,
    created_at
from {{ ref('fct_orders') }}
where created_at > {{ dbt.current_timestamp() }}
