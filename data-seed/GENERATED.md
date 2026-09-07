# data-seed/ — how these CSVs are generated, and when to regenerate

These files are **generated output**, not hand-maintained data. `scripts/generate_data.py`
writes all six of them from a single anchor date. Edit the script, not the CSVs.

## Why this file exists

Several models and commands in this project filter on wall-clock time:

| Where | Window |
|---|---|
| `limit_data_in_dev()` on `stg_audit_events` (dev/ci targets) | last 30 days |
| `mv_recent_orders` | last 7 days |
| `dbt build --sample '<n> days'` | last *n* days |
| `dbt source freshness` | `now() - max(loaded_at)` vs `warn_after` / `error_after` |
| `dim_customer_segments_v2` recency bands | 90 / 365 days |
| `fct_orders` future-order rule | `created_at <= current_timestamp` |

A fixture whose newest row sits in the past turns every one of those into **zero rows** —
and zero rows still pass `not_null` and `unique`, so the project goes green while teaching
nothing. That is the failure mode this generation scheme exists to prevent.

## The fixture as committed

| | |
|---|---|
| Anchor | **2026-09-01** |
| Business-timestamp window | **2025-01-09 → 2028-09-30** (1361 days: anchor − 600 d, anchor + 760 d) |
| Newest `loaded_at` | **2028-09-30** (~2 years past the anchor) |
| Forward horizon expires | around **2028-09-30** |

Row counts:

| File | Rows | Notes |
|---|---:|---|
| `customers.csv` | 200 | `customer_id` 1–10 are kept in the past on purpose — see below |
| `products.csv` | 50 | all created before the order window opens |
| `orders.csv` | 4,000 | 1,767 on/before the anchor, 2,233 after (scheduled / pre-orders) |
| `order_items.csv` | 10,386 | 1–8 lines per order |
| `audit_events.csv` | 6,000 | `event_id` ascends with `occurred_at` |
| `currency_rates.csv` | 5 | one row per currency; `rate_as_of` = end of window |

Density, which is the property that actually matters:

- **every calendar day** in the window carries **at least 2 orders** (avg 2.94/day), so no
  `--sample` window of any length can come back empty;
- **every calendar day** carries **at least 1 audit event** (avg 4.41/day).

`loaded_at` is always the row's business timestamp plus a **1–6 hour ingestion jitter**, so
the newest `loaded_at` also sits ~2 years ahead and `dbt source freshness` **passes** on a
fresh clone for the whole runway.

## Regenerating

From the repo root:

```bash
python scripts/generate_data.py --anchor 2026-09-01
```

Omit `--anchor` to anchor on today (UTC). Other knobs: `--back-days`, `--forward-days`,
`--orders`, `--audit-events`, `--customers`, `--products`, `--seed`, `--out-dir`.

The generator runs a **self-check before it writes anything** and refuses to emit a fixture
that would decay: it verifies the per-day order and audit-event floors, that every 3-day
window contains orders, that every freshness-checked table has ≥ 2 years of forward
`loaded_at` runway, that orders exist on both sides of the anchor, referential integrity,
that `order_total_cents` equals the sum of its lines, and that no order predates its
customer's signup. A violation raises and nothing is written.

Then reload the warehouse. The devcontainer bind-mounts `data-seed/` read-only at
`/data-seed`, so the container sees new files immediately:

```bash
# fresh clone / fresh volume: db-init/*.sql runs automatically
docker compose -f .devcontainer/docker-compose.yml down -v && \
docker compose -f .devcontainer/docker-compose.yml up -d

# existing volume: truncate and re-COPY
psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "truncate raw_ecom.order_items, raw_ecom.orders, raw_ecom.audit_events,
            raw_ecom.customers, raw_ecom.products, raw_ref.currency_rates;"
psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f db-init/04-load-raw.sql

dbt build --full-refresh
```

If you change the anchor, also move `begin` on `models/marts/fct_orders_microbatch.sql` to
the new window start — dbt would otherwise build empty batches back to the old date.

> **Regeneration rule — regenerate when the forward horizon drops below ~6 months.**
> With the committed anchor that means **before ~April 2028**. Re-run with a fresh
> `--anchor`, reload, rebuild, and update the numbers in this file.

## The two freshness outcomes

Because the fixture is generated forward, `dbt source freshness` passes by default. STALE is
the more instructive outcome, so it is reachable on demand:

```bash
# force every source STALE  ->  `dbt source freshness` reports STALE and exits 1
psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f scripts/force_stale.sql
dbt source freshness

# restore  ->  PASS, exit 0
psql -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f scripts/restore_freshness.sql
dbt source freshness
```

`force_stale.sql` computes the shift from the data (it does not hardcode an interval), lands
the newest row 8 days in the past — beyond `error_after` on every configured source — and
records the exact interval in `raw_ecom._freshness_shift` so `restore_freshness.sql` is a
true inverse. Running it twice is refused rather than compounding.

Not to be confused with `scripts/rotate_loaded_at.sql`, which does the opposite: it pushes 50
order rows *past* the current maximum so `dbt build --select source_status:fresher+` has
something to select against a frozen `sources.json` baseline.

## Deliberate quirks worth knowing

- **Future-dated orders are a feature.** Read them as scheduled or pre-ordered.
  `stg_orders` keeps them; `fct_orders` filters them out with
  `created_at <= {{ dbt.current_timestamp() }}`; `tests/assert_no_future_orders.sql` asserts
  the mart holds none. That is the layer-responsibility lesson: business rules belong in the
  mart, not in staging. It also means `fct_orders`'s row count **grows over time** — do not
  assert a fixed number against it.
- **`customer_id` 1–10 always have a past `updated_at`.** `scripts/mutate-customers.sql`
  writes `updated_at = now()` to trigger a new SCD2 version in the timestamp-strategy
  snapshot; that only works if the existing value is older. The generator enforces this and
  the self-check verifies it.
- **`currency_rates` has one row per currency, not one per day.** `models/sources.yml`
  asserts `unique` on `currency_code` and `fct_orders` joins on it alone, so a rate history
  would fan out the fact table. `rate_as_of` is the end of the window: one rate, in force for
  every day the fixture covers.
- **`event_id` and `order_id` ascend with time.** The append-strategy demo uses
  `id > max(id)` as its watermark, which is only sound if the surrogate key is monotonic in
  event time.
