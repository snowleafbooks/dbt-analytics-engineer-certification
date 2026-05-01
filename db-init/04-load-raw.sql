-- Populate raw tables from /data-seed CSVs. The CSVs include a header row.

\COPY raw_ecom.customers    FROM '/data-seed/customers.csv'    WITH (FORMAT csv, HEADER true);
\COPY raw_ecom.products     FROM '/data-seed/products.csv'     WITH (FORMAT csv, HEADER true);
\COPY raw_ecom.orders       FROM '/data-seed/orders.csv'       WITH (FORMAT csv, HEADER true);
\COPY raw_ecom.order_items  FROM '/data-seed/order_items.csv'  WITH (FORMAT csv, HEADER true);
\COPY raw_ecom.audit_events FROM '/data-seed/audit_events.csv' WITH (FORMAT csv, HEADER true);
