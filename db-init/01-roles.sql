-- Roles consumed by models/ `grants:` configs.
-- The dbt_developer role connects as POSTGRES_USER and needs CREATE on the target database.
-- bi_reader, analytics_reader, finance_reader, marketing_reader exist only so GRANT SELECT lands on a real grantee.

CREATE ROLE bi_reader NOLOGIN;
CREATE ROLE analytics_reader NOLOGIN;
CREATE ROLE finance_reader NOLOGIN;
CREATE ROLE marketing_reader NOLOGIN;

GRANT CONNECT ON DATABASE dbtae TO bi_reader, analytics_reader, finance_reader, marketing_reader;
