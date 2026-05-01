-- v=99 does not exist; only v=1 and v=2 are declared in dim_customer_segments.yml.
select * from {{ ref('dim_customer_segments', v=99) }}
