{#
    Singular test demonstrating SEVERITY THRESHOLDS: `warn_if` and `error_if`.

    The business control: finance manually reviews unusually large orders. A handful in a
    month is normal. Eight or more is worth a warning. Thirty or more means something
    upstream is wrong -- a currency mix-up, a duplicated cart, a bad rate -- and the build
    should stop.

    HOW THE THREE OUTCOMES ARE PRODUCED. dbt wraps this query as

        select count(*) as failures,
               count(*) >= 8  as should_warn,
               count(*) >= 30 as should_error
        from ( <this query> ) dbt_internal_test

    and then decides: `should_error` -> FAIL, else `should_warn` -> WARN, else PASS. So a
    singular test is not simply "returns rows = failed". `warn_if` / `error_if` turn the
    returned row count into a graded signal, which is the whole reason they exist.

    NOTE THE SEVERITY. This is `severity='error'`, not `'warn'`. dbt only consults
    `should_error` when severity is `error` (dbt/task/test.py: `if severity == "ERROR" and
    result.should_error`). Set `severity='warn'` here and `error_if` becomes unreachable --
    the test could warn but never block. If you want a test that can escalate, the severity
    must be `error` and `warn_if` is what softens it below the error threshold.

    SEE ALL THREE OUTCOMES, one knob, real fixture data:

        dbt test --select assert_large_orders_within_review_tolerance
            -> PASS.  Default threshold $1,000; a couple of such orders in a 30-day window.

        dbt test --select assert_large_orders_within_review_tolerance \
                 --vars '{large_order_review_usd: 500}'
            -> WARN.  About 20 orders clear $500 in 30 days: >= warn_if (8), < error_if (30).
               "Got <n> results, configured to warn if >= 8"

        dbt test --select assert_large_orders_within_review_tolerance \
                 --vars '{large_order_review_usd: 150}'
            -> FAIL.  About 64 orders clear $150: >= error_if (30).
               "Got <n> results, configured to fail if >= 30"

    Add `--warn-error` to the middle command and the WARN becomes a build-blocking failure
    too -- that flag escalates warnings globally, which is a different lever from `error_if`.

    Expect the exact counts to move a little day to day. The 30-day window is what keeps
    them in a band rather than growing without bound: the population is a rolling window, not
    the whole history, so the three OUTCOMES are stable even though the numerators drift as
    the fixture's forward-dated orders mature.
#}
{{ config(
    severity='error',
    warn_if='>= 8',
    error_if='>= 30',
    tags=['critical']
) }}

select
    order_id,
    customer_id,
    currency,
    order_total_usd,
    created_at
from {{ ref('fct_orders') }}
where created_at >= current_date - interval '30 days'
  and order_total_usd > {{ var('large_order_review_usd', 1000) }}
