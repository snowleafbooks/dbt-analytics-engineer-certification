{#
    SQL-block snapshot, `check` strategy, with `check_cols='all'`.

    `all` is safe here and only here, and the SELECT below is the reason: it projects six
    business columns and deliberately leaves out `created_at`, `updated_at` and `loaded_at`.
    "All" therefore means "all six things a human would call a change to a product". Compare
    snapshots/_snapshots.yml, where the YAML `relation:` form cannot drop those columns and
    so has to name its check columns explicitly.

    That is the general rule: `check_cols: all` is a statement about the projection, not
    about the table. Point it at a raw relation with audit or load timestamps and every
    re-load mints a spurious SCD2 version.

    `hard_deletes='new_record'` writes a closing row with `dbt_is_deleted = 'True'` when a
    product disappears from the source, rather than silently leaving the last version open.
    `dbt_valid_to_current` puts a sentinel high date in `dbt_valid_to` on the current row, so
    downstream `between` predicates work without a NULL guard.
#}
{% snapshot snp_products_check %}

    {{ config(
        schema='snapshots',
        unique_key='product_id',
        strategy='check',
        check_cols='all',
        hard_deletes='new_record',
        dbt_valid_to_current="'9999-12-31'::timestamp"
    ) }}

    select
        product_id,
        sku,
        name as product_name,
        category_id,
        price_cents,
        is_active
    from {{ source('raw_ecom', 'product_catalog') }}

{% endsnapshot %}
