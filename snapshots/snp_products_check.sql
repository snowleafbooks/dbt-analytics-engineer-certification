{% snapshot snp_products_check %}

    {{ config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='check',
        check_cols=['product_name', 'price_cents', 'is_active']
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
