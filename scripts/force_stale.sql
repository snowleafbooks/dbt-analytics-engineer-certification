-- Force every freshness-checked source to report STALE.
--
-- WHY THIS EXISTS
-- The data-seed fixture is generated ~2 years into the future (see data-seed/GENERATED.md),
-- which is what makes `dbt source freshness` PASS on a fresh clone for the whole runway.
-- That is the right default, but it means the *other* outcome -- the one worth studying --
-- is no longer reachable by waiting. This script shifts every `loaded_at` backwards far
-- enough that the newest row is 8 days old, which is past `error_after` on every source
-- configured in models/sources.yml (12h on raw_ecom.orders, 24h on the rest of raw_ecom,
-- 7 days on raw_ref.currency_rates).
--
-- The shift is computed from the data, not hardcoded, so this keeps working as the fixture
-- is re-cut. It is recorded in raw_ecom._freshness_shift so the move is exactly reversible.
--
-- USAGE
--   PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB \
--     -f scripts/force_stale.sql
--   dbt source freshness            # every source STALE, exit code 1
--   PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB \
--     -f scripts/restore_freshness.sql
--   dbt source freshness            # PASS again, exit code 0
--
-- Not to be confused with scripts/rotate_loaded_at.sql, which pushes a few rows *newer*
-- so `source_status:fresher+` has something to select.

\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS raw_ecom._freshness_shift (
    id          integer PRIMARY KEY DEFAULT 1,
    shift       interval NOT NULL,
    applied_at  timestamp NOT NULL DEFAULT now(),
    CONSTRAINT _freshness_shift_singleton CHECK (id = 1)
);

DO $$
DECLARE
    v_newest timestamp;
    v_shift  interval;
BEGIN
    IF EXISTS (SELECT 1 FROM raw_ecom._freshness_shift) THEN
        RAISE EXCEPTION
            'a freshness shift is already applied; run scripts/restore_freshness.sql first';
    END IF;

    SELECT max(m) INTO v_newest FROM (
        SELECT max(loaded_at) AS m FROM raw_ecom.customers
        UNION ALL SELECT max(loaded_at) FROM raw_ecom.products
        UNION ALL SELECT max(loaded_at) FROM raw_ecom.orders
        UNION ALL SELECT max(loaded_at) FROM raw_ecom.order_items
        UNION ALL SELECT max(loaded_at) FROM raw_ecom.audit_events
        UNION ALL SELECT max(loaded_at) FROM raw_ref.currency_rates
    ) AS newest;

    -- Land the newest row 8 days in the past: beyond the widest error_after (7 days).
    v_shift := v_newest - (now()::timestamp - interval '8 days');

    IF v_shift <= interval '0' THEN
        RAISE EXCEPTION
            'sources are already stale (newest loaded_at is %); nothing to do', v_newest;
    END IF;

    UPDATE raw_ecom.customers      SET loaded_at = loaded_at - v_shift;
    UPDATE raw_ecom.products       SET loaded_at = loaded_at - v_shift;
    UPDATE raw_ecom.orders         SET loaded_at = loaded_at - v_shift;
    UPDATE raw_ecom.order_items    SET loaded_at = loaded_at - v_shift;
    UPDATE raw_ecom.audit_events   SET loaded_at = loaded_at - v_shift;
    UPDATE raw_ref.currency_rates  SET loaded_at = loaded_at - v_shift;

    INSERT INTO raw_ecom._freshness_shift (id, shift) VALUES (1, v_shift);

    RAISE NOTICE 'shifted every loaded_at back by %; newest row is now %',
        v_shift, v_newest - v_shift;
END
$$;

SELECT 'raw_ecom.orders'        AS source_table, max(loaded_at) AS newest_loaded_at,
       now()::timestamp - max(loaded_at) AS age FROM raw_ecom.orders
UNION ALL
SELECT 'raw_ref.currency_rates', max(loaded_at), now()::timestamp - max(loaded_at)
  FROM raw_ref.currency_rates;
