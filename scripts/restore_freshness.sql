-- Undo scripts/force_stale.sql: put every `loaded_at` back where it was and make
-- `dbt source freshness` PASS again.
--
-- The exact interval that force_stale.sql subtracted is recorded in
-- raw_ecom._freshness_shift, so this is a true inverse rather than an approximation.
--
-- USAGE
--   PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB \
--     -f scripts/restore_freshness.sql
--   dbt source freshness            # PASS, exit code 0

\set ON_ERROR_STOP on

DO $$
DECLARE
    v_shift interval;
BEGIN
    IF to_regclass('raw_ecom._freshness_shift') IS NULL THEN
        RAISE EXCEPTION 'no freshness shift recorded; scripts/force_stale.sql was never run';
    END IF;

    SELECT shift INTO v_shift FROM raw_ecom._freshness_shift WHERE id = 1;

    IF v_shift IS NULL THEN
        RAISE EXCEPTION 'no freshness shift recorded; sources are already at full freshness';
    END IF;

    UPDATE raw_ecom.customers      SET loaded_at = loaded_at + v_shift;
    UPDATE raw_ecom.products       SET loaded_at = loaded_at + v_shift;
    UPDATE raw_ecom.orders         SET loaded_at = loaded_at + v_shift;
    UPDATE raw_ecom.order_items    SET loaded_at = loaded_at + v_shift;
    UPDATE raw_ecom.audit_events   SET loaded_at = loaded_at + v_shift;
    UPDATE raw_ref.currency_rates  SET loaded_at = loaded_at + v_shift;

    DELETE FROM raw_ecom._freshness_shift WHERE id = 1;

    RAISE NOTICE 'restored every loaded_at by +%', v_shift;
END
$$;

SELECT 'raw_ecom.orders'        AS source_table, max(loaded_at) AS newest_loaded_at,
       max(loaded_at) - now()::timestamp AS runway FROM raw_ecom.orders
UNION ALL
SELECT 'raw_ref.currency_rates', max(loaded_at), max(loaded_at) - now()::timestamp
  FROM raw_ref.currency_rates;
