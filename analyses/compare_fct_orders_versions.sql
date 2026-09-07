{#
    Analysis: audit_helper.compare_relations over two genuinely different relations.

    Run:
        dbt compile --select resource_type:analysis
    Then paste target/compiled/dbtae_companion/analyses/compare_fct_orders_versions.sql
    into psql. (`--select analysis:<name>` does NOT work -- dbt has no `analysis` selector
    method and exits with "'analysis' is not a valid method name". Select an analysis by
    node name or by `resource_type:analysis`.)

    `compare_relations` returns one row per (in_a, in_b) combination with a row count and a
    percent-of-total: rows only in A, rows only in B, and rows present in both.

    WHAT IS BEING COMPARED, AND WHY IT IS NOT A SELF-COMPARISON. `fct_orders` and
    `fct_orders_microbatch` are two independently-materialised views of the same order
    stream: the first is a delete+insert incremental that filters at the mart boundary, the
    second is a microbatch model that processes whole calendar months up to the current one.
    They overlap on `order_id` but do not agree, and the disagreement is the lesson. The two
    models cut the stream at different GRANULARITIES: `fct_orders` filters at the exact
    instant of the run (`created_at <= current_timestamp`), while the microbatch model
    processes whole calendar months, so the current month's batch already carries every order
    dated later in the month. The B-only rows are therefore the remainder of the current
    calendar month -- rows the month batch has merged and the instant-cut mart has not
    reached -- and how many there are depends on how far into the month you run: a handful
    near a month end, most of a month's orders on the 1st. Measured 2026-09-01:

        in_a | in_b | count | percent_of_total
        -----+------+-------+------------------
        t    | t    |  1771 |            95.06
        f    | t    |    92 |             4.94

    A `lookback` window not yet re-run shows up the same way. Pointing both arguments at the
    same relation, which this analysis used to do, can only ever report a perfect match: a
    reconciliation tool that cannot report a difference is not a reconciliation tool.

    `exclude_columns` drops the columns that legitimately differ row-by-row (the two models
    do not project the same shape), leaving the primary key and the business measures.
    `compare_relations` requires the two relations to share the compared columns, so the
    comparison is scoped to what both actually have.
#}

{{ audit_helper.compare_relations(
    a_relation=ref('fct_orders'),
    b_relation=ref('fct_orders_microbatch'),
    primary_key='order_id',
    exclude_columns=[
        'country_code', 'country_name', 'order_total_cents', 'order_total_usd',
        'created_at', 'updated_at', 'loaded_at', 'dbt_updated_at', 'order_created_at'
    ]
) }}
