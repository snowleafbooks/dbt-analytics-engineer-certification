{% snapshot snp_products_check_all %}

    {{ config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='check',
        check_cols='all'
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
