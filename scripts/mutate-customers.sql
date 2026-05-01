-- Bumps one customer's email + updated_at so the next `dbt snapshot` captures a new
-- SCD2 version. Run between two `dbt snapshot` invocations to watch dbt_valid_from /
-- dbt_valid_to populate.
--
-- Usage:
--   PGPASSWORD=$POSTGRES_PASSWORD psql \
--     -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB \
--     -f scripts/mutate-customers.sql

UPDATE raw_ecom.customers
   SET email      = 'updated+' || customer_id || '@example.com',
       updated_at = now()
 WHERE customer_id = 7;

SELECT customer_id, email, updated_at
  FROM raw_ecom.customers
 WHERE customer_id = 7;
