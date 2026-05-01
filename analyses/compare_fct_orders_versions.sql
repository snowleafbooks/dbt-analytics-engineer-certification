{#
    Analysis: compare two versions of fct_orders using audit_helper.
    Run:
        dbt compile --select analysis:compare_fct_orders_versions
    Then paste target/compiled/.../compare_fct_orders_versions.sql into psql.

    `audit_helper.compare_relations` returns a two-column summary: in_a_not_in_b, in_b_not_in_a, etc.
#}

{{ audit_helper.compare_relations(
    a_relation=ref('fct_orders'),
    b_relation=ref('fct_orders'),
    primary_key='order_id',
    exclude_columns=['dbt_updated_at', 'loaded_at']
) }}
