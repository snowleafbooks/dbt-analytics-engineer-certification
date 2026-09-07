-- Populate raw tables from /data-seed CSVs. The CSVs include a header row.
--
-- The CSVs are generated relative to an anchor date by scripts/generate_data.py, so their
-- business timestamps run from ~600 days before the anchor to ~760 days after it. That
-- forward leg is what keeps `source freshness`, `--sample`, `mv_recent_orders` and the
-- dev-mode 30-day filter returning rows on a fresh clone. See data-seed/GENERATED.md.

\COPY raw_ecom.customers      FROM '/data-seed/customers.csv'      WITH (FORMAT csv, HEADER true);
\COPY raw_ecom.products       FROM '/data-seed/products.csv'       WITH (FORMAT csv, HEADER true);
\COPY raw_ecom.orders         FROM '/data-seed/orders.csv'         WITH (FORMAT csv, HEADER true);
\COPY raw_ecom.order_items    FROM '/data-seed/order_items.csv'    WITH (FORMAT csv, HEADER true);
\COPY raw_ecom.audit_events   FROM '/data-seed/audit_events.csv'   WITH (FORMAT csv, HEADER true);
\COPY raw_ref.currency_rates  FROM '/data-seed/currency_rates.csv' WITH (FORMAT csv, HEADER true);
