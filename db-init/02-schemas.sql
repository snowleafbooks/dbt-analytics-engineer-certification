-- Raw schemas source() points at. Target schemas are created by dbt on-run-start.

CREATE SCHEMA IF NOT EXISTS raw_ecom AUTHORIZATION dbt_developer;
CREATE SCHEMA IF NOT EXISTS raw_ref  AUTHORIZATION dbt_developer;

GRANT USAGE ON SCHEMA raw_ecom TO bi_reader, analytics_reader, finance_reader, marketing_reader;
GRANT USAGE ON SCHEMA raw_ref  TO bi_reader, analytics_reader, finance_reader, marketing_reader;

ALTER DEFAULT PRIVILEGES IN SCHEMA raw_ecom GRANT SELECT ON TABLES TO analytics_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw_ref  GRANT SELECT ON TABLES TO analytics_reader;
