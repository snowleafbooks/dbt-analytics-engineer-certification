{#
    Singular test: an order's total must equal the sum of its line items (in cents).

    THIS FILE IS ALSO THE `fail_calc` FIXTURE.

    `fail_calc` is the expression dbt puts in the `failures` column of the wrapper it builds
    around every data test:

        select
          {{ fail_calc }} as failures,
          {{ fail_calc }} {{ warn_if }} as should_warn,
          {{ fail_calc }} {{ error_if }} as should_error
        from ( <the test query> ) dbt_internal_test

    It defaults to `count(*)`, which is why "a test fails when it returns rows" is the usual
    shorthand -- and why `warn_if` / `error_if` (see assert_large_orders_within_review_tolerance)
    read as row-count thresholds. The default is not asserted here; it is visible verbatim in
    the wrapper dbt generates for every other test in this project:

        dbt build
        head -6 target/run/dbtae_companion/tests/assert_no_future_orders.sql

    Here the count of bad orders is the less useful number. The MAGNITUDE of the break is what
    finance cares about, so `fail_calc` sums the absolute discrepancy in cents. `failures` then
    reports cents, not rows.

    THE ZERO-ROW TRAP, AND IT IS A HARD ERROR RATHER THAN A QUIET NULL. `sum()` over zero rows
    returns NULL in every SQL dialect, and a healthy dataset is exactly the case where this
    test returns zero rows. Both arms ship, switched by a var, so the trap runs rather than
    being described. Observed on dbt-core 1.11.14 / dbt-postgres 1.11.0, 2026-09-03:

        dbt test --select assert_fct_orders_amount_matches_items
            -> PASS. `coalesce(sum(...), 0)` turns the empty-set NULL into 0.
               Done. PASS=3 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=3   # + 2 project hooks

        dbt test --select assert_fct_orders_amount_matches_items --vars '{unsafe_fail_calc: true}'
            -> ERROR, exit 1, and note that it is not a test failure at all:

                 Failure in test assert_fct_orders_amount_matches_items
                   None is not of type 'integer'
                   Failed validating 'type' in schema['properties']['failures']:
                       {'type': 'integer'}
                   On instance['failures']:
                       None

               dbt validates the agate row against a schema that requires an integer
               `failures`, so a NULL fail_calc breaks the test harness before any threshold is
               consulted. The test that "passes on clean data" is the one that cannot run on
               clean data.

    `coalesce(...)` is used rather than a `case` expression only because it is shorter; a
    `case when count(*) = 0 then 0 else sum(...) end` behaves identically.
#}
{{ config(
    fail_calc = "sum(abs(order_total_cents - items_total_cents))"
                if var('unsafe_fail_calc', false)
                else "coalesce(sum(abs(order_total_cents - items_total_cents)), 0)"
) }}
with order_totals as (
    select
        order_id,
        order_total_cents
    from {{ ref('fct_orders') }}
),
item_totals as (
    select
        order_id,
        sum(line_total_cents) as items_total_cents
    from {{ ref('fct_order_items') }}
    group by 1
)

{#
    LEFT JOIN, AND BOTH `coalesce`s ARE LOAD-BEARING.

    An inner join here would compare only the orders that still HAVE line items, which quietly
    excludes the worst outcome this test exists to catch. Measured, 2026-09-06: delete every
    line of order 1 from `fct_order_items`, leave its `order_total_cents` at 15996, and the
    inner-join form reported PASS=3, exit 0 -- the order's entire value vanished from the child
    fact and the reconciliation agreed with itself.

    The `where` coalesce is what SELECTS the row; the coalesce in the projection is what lets
    `fail_calc` MEASURE it. Fix only the `where` and the row is returned with a NULL
    `items_total_cents`, `abs(order_total_cents - NULL)` is NULL, and the configured
    `coalesce(sum(...), 0)` turns the sum of one NULL into 0 failures -- a PASS on the row it
    just selected. Both, or neither.
#}
select
    o.order_id,
    o.order_total_cents,
    coalesce(i.items_total_cents, 0) as items_total_cents
from order_totals o
left join item_totals i using (order_id)
where o.order_total_cents != coalesce(i.items_total_cents, 0)
