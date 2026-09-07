-- DDL for raw tables. `loaded_at` timestamps drive `source freshness` and incremental demos.

CREATE TABLE raw_ecom.customers (
    customer_id       INTEGER PRIMARY KEY,
    email             VARCHAR(120) NOT NULL,
    first_name        VARCHAR(60),
    last_name         VARCHAR(60),
    country_code      VARCHAR(2),
    address_line_1    VARCHAR(200),
    city              VARCHAR(80),
    postal_code       VARCHAR(20),
    signed_up_at      TIMESTAMP,
    updated_at        TIMESTAMP,
    loaded_at         TIMESTAMP
);

CREATE TABLE raw_ecom.products (
    product_id        INTEGER PRIMARY KEY,
    sku               VARCHAR(40) UNIQUE NOT NULL,
    name              VARCHAR(120) NOT NULL,
    category_id       INTEGER,
    price_cents       INTEGER NOT NULL,
    is_active         BOOLEAN,
    created_at        TIMESTAMP,
    updated_at        TIMESTAMP,
    loaded_at         TIMESTAMP
);

CREATE TABLE raw_ecom.orders (
    order_id          INTEGER PRIMARY KEY,
    customer_id       INTEGER NOT NULL,
    status            VARCHAR(20) NOT NULL,
    order_total_cents INTEGER NOT NULL,
    currency          VARCHAR(3) NOT NULL,
    created_at        TIMESTAMP NOT NULL,
    updated_at        TIMESTAMP,
    loaded_at         TIMESTAMP
);

CREATE TABLE raw_ecom.order_items (
    order_id          INTEGER NOT NULL,
    line_no           INTEGER NOT NULL,
    product_id        INTEGER NOT NULL,
    quantity          INTEGER NOT NULL,
    unit_price_cents  INTEGER NOT NULL,
    loaded_at         TIMESTAMP,
    PRIMARY KEY (order_id, line_no)
);

CREATE TABLE raw_ecom.audit_events (
    event_id          BIGINT PRIMARY KEY,
    entity            VARCHAR(40) NOT NULL,
    entity_id         INTEGER NOT NULL,
    action            VARCHAR(40) NOT NULL,
    occurred_at       TIMESTAMP NOT NULL,
    loaded_at         TIMESTAMP
);

-- Second source in a different schema — demonstrates the "source = (db, schema)" counting rule.
CREATE TABLE raw_ref.currency_rates (
    currency_code     VARCHAR(3) PRIMARY KEY,
    usd_per_unit      NUMERIC(12, 6) NOT NULL,
    rate_as_of        DATE NOT NULL,
    loaded_at         TIMESTAMP
);

-- Rows for every raw table, currency_rates included, come from data-seed/*.csv in
-- 04-load-raw.sql. Nothing here hardcodes a date: the CSVs are cut relative to an anchor
-- by scripts/generate_data.py, so the fixture stays inside every relative-time window the
-- project uses. See data-seed/GENERATED.md.
