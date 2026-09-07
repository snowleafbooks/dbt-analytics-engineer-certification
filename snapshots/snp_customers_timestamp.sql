{% snapshot snp_customers_timestamp %}

    {{ config(
        schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        hard_deletes='ignore'
    ) }}

    select
        customer_id,
        email,
        first_name,
        last_name,
        country_code,
        address_line_1,
        city,
        postal_code,
        updated_at
    from {{ source('raw_ecom', 'customers') }}

{% endsnapshot %}
