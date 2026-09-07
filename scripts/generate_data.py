#!/usr/bin/env python3
"""
Regenerate the data-seed/ CSVs.

Every timestamp in this fixture is derived from a single ``--anchor`` date. Nothing
is hardcoded to an absolute calendar date, so the data set can be re-cut at any time
by re-running the script.

Why the window is asymmetric
----------------------------
Business timestamps span ``ANCHOR - BACK_DAYS`` through ``ANCHOR + FORWARD_DAYS``
(600 back, 760 forward by default). The backward leg gives the project enough history
for rollups, snapshots and incremental demos. The forward leg is what stops the
fixture decaying: several models here filter on wall-clock time
(``limit_data_in_dev`` keeps 30 days, ``mv_recent_orders`` keeps 7 days, ``--sample``
slices a few days, ``dbt source freshness`` compares ``loaded_at`` to ``now()``).
A fixture whose newest row is in the past turns every one of those into an empty
result -- and an empty result still passes ``not_null`` and ``unique``, so the failure
is silent. Generating more than two years of forward data means a reader who clones
this repo at any point in that runway still sees rows everywhere.

Forward-dated orders are a deliberate feature, not an artefact: read them as
scheduled or pre-ordered. ``models/marts/fct_orders.sql`` applies the business rule
that keeps them out of the mart, and ``tests/assert_no_future_orders.sql`` asserts
the mart holds none.

``loaded_at`` is always the row's business timestamp plus a 1-6 hour ingestion
jitter, so the newest ``loaded_at`` also sits ~2 years ahead and
``dbt source freshness`` passes on a fresh clone. To see the *stale* outcome -- the
more instructive one -- run ``scripts/force_stale.sql``; ``scripts/restore_freshness.sql``
puts it back. See ``data-seed/GENERATED.md``.

Stdlib only. Run from the repo root:

    python scripts/generate_data.py --anchor 2026-09-01
"""
from __future__ import annotations

import argparse
import csv
import random
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path

# --- defaults -------------------------------------------------------------------
SEED = 20240101
BACK_DAYS = 600
FORWARD_DAYS = 760

NUM_CUSTOMERS = 200
NUM_PRODUCTS = 50
NUM_ORDERS = 4000
NUM_AUDIT_EVENTS = 6000
AVG_ITEMS_PER_ORDER = 3

# Density floors. These are what make the density guarantee hold by construction
# rather than by luck: at ~2.9 orders/day the Poisson tail would leave a handful of
# empty days scattered through the window, and `--sample '3 days'` would return
# nothing whenever it landed on one.
MIN_ORDERS_PER_DAY = 2
MIN_AUDIT_EVENTS_PER_DAY = 1

# Customer ids reserved for the demo scripts that mutate a source row and set
# `updated_at = now()` (scripts/mutate-customers.sql). Their `updated_at` is kept in
# the past so that a `now()` write is still an increase, which is what the timestamp
# snapshot strategy needs in order to record a new SCD2 version.
DEMO_CUSTOMER_IDS = set(range(1, 11))

OUT_DIR_DEFAULT = Path(__file__).resolve().parent.parent / "data-seed"

COUNTRIES = ["US", "GB", "CA", "AU", "DE", "FR", "NL", "IE", "ES", "IT"]
COUNTRY_CITIES = {
    "US": ["Seattle", "Austin", "Denver", "Boston", "Miami"],
    "GB": ["London", "Manchester", "Bristol", "Leeds", "Glasgow"],
    "CA": ["Toronto", "Vancouver", "Montreal", "Calgary", "Ottawa"],
    "AU": ["Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide"],
    "DE": ["Berlin", "Munich", "Hamburg", "Frankfurt", "Cologne"],
    "FR": ["Paris", "Lyon", "Marseille", "Toulouse", "Nice"],
    "NL": ["Amsterdam", "Rotterdam", "Utrecht", "The Hague", "Eindhoven"],
    "IE": ["Dublin", "Cork", "Galway", "Limerick", "Waterford"],
    "ES": ["Madrid", "Barcelona", "Valencia", "Seville", "Bilbao"],
    "IT": ["Rome", "Milan", "Naples", "Turin", "Florence"],
}
CURRENCY_BY_COUNTRY = {
    "US": "USD", "CA": "CAD", "AU": "AUD", "GB": "GBP",
    "DE": "EUR", "FR": "EUR", "NL": "EUR", "IE": "EUR", "ES": "EUR", "IT": "EUR",
}
# usd_per_unit for the raw_ref.currency_rates reference table.
USD_PER_UNIT = {
    "USD": "1.000000",
    "EUR": "1.085000",
    "GBP": "1.274000",
    "CAD": "0.732000",
    "AUD": "0.662000",
}
FIRST_NAMES = ["Alex", "Sam", "Jordan", "Taylor", "Casey", "Morgan", "Avery", "Riley",
               "Quinn", "Sage", "Rowan", "Blake", "Drew", "Finley", "Hayden", "Kai",
               "Logan", "Micah", "Noah", "Parker", "Reese", "Skyler", "Toby", "Vale"]
LAST_NAMES = ["Smith", "Johnson", "Lee", "Patel", "Brown", "Garcia", "Müller", "Silva",
              "Nguyen", "Kowalski", "O'Brien", "Kim", "Davies", "Romano", "Fischer",
              "Martin", "Dubois", "Van Dijk", "Chen", "Hernandez"]
STATUSES = ["pending", "paid", "shipped", "delivered", "refunded", "cancelled"]
STATUS_WEIGHTS = [5, 20, 20, 40, 10, 5]
PRODUCT_CATEGORIES = [
    (1, "apparel"),
    (2, "footwear"),
    (3, "accessories"),
    (4, "home"),
    (5, "electronics"),
    (6, "outdoors"),
]
PRODUCT_ADJECTIVES = ["Classic", "Modern", "Eco", "Pro", "Lite", "Heritage",
                      "Everyday", "Alpine", "Coastal", "Urban"]
PRODUCT_NOUNS = {
    1: ["Tee", "Hoodie", "Jacket", "Sweater", "Pants"],
    2: ["Sneaker", "Boot", "Runner", "Slip-On", "Sandal"],
    3: ["Bag", "Cap", "Belt", "Wallet", "Scarf"],
    4: ["Mug", "Blanket", "Lamp", "Candle", "Pillow"],
    5: ["Headphones", "Charger", "Speaker", "Cable", "Webcam"],
    6: ["Tent", "Daypack", "Bottle", "Stove", "Mat"],
}

TS_FMT = "%Y-%m-%d %H:%M:%S"


# --- helpers --------------------------------------------------------------------
def ts(d: datetime) -> str:
    return d.strftime(TS_FMT)


def rand_dt(rng: random.Random, start: datetime, end: datetime) -> datetime:
    """Uniform datetime in [start, end]; tolerates end < start by clamping."""
    if end < start:
        end = start
    delta = int((end - start).total_seconds())
    return start + timedelta(seconds=rng.randint(0, delta))


def rand_dt_on_day(rng: random.Random, day: date) -> datetime:
    return datetime.combine(day, time(0, 0)) + timedelta(seconds=rng.randint(0, 86399))


def ingest(rng: random.Random, business_ts: datetime) -> datetime:
    """loaded_at = business timestamp + a 1-6 hour ingestion jitter."""
    return business_ts + timedelta(seconds=rng.randint(3600, 6 * 3600))


def spread(rng: random.Random, total: int, floor: int, days: list) -> dict:
    """Allocate `total` rows across `days`, giving every day at least `floor`."""
    base = floor * len(days)
    if total < base:
        raise SystemExit(
            "volume too low: {} rows cannot give {} per day across {} days "
            "(need at least {}). Raise the count or shorten the window.".format(
                total, floor, len(days), base)
        )
    counts = {d: floor for d in days}
    for _ in range(total - base):
        counts[rng.choice(days)] += 1
    return counts


def _write_csv(out_dir: Path, name: str, rows, fieldnames) -> None:
    path = out_dir / name
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def _parse(value: str) -> datetime:
    return datetime.strptime(value, TS_FMT)


# --- generation -----------------------------------------------------------------
def build(args) -> dict:
    rng = random.Random(args.seed)

    anchor = datetime.combine(args.anchor, time(0, 0))
    window_start = anchor - timedelta(days=args.back_days)
    window_end = anchor + timedelta(days=args.forward_days)
    days = [(window_start + timedelta(days=i)).date()
            for i in range((window_end - window_start).days + 1)]

    # --- customers ---
    customers = []
    for cid in range(1, args.customers + 1):
        country = rng.choice(COUNTRIES)
        city = rng.choice(COUNTRY_CITIES[country])
        first = rng.choice(FIRST_NAMES)
        last = rng.choice(LAST_NAMES)

        if cid in DEMO_CUSTOMER_IDS:
            # Early adopters, and deliberately never updated in the forward half of
            # the window -- see DEMO_CUSTOMER_IDS above.
            signed = rand_dt(rng, window_start - timedelta(days=300), window_start)
            updated = rand_dt(rng, signed, anchor - timedelta(days=30))
        else:
            signed = rand_dt(rng, window_start - timedelta(days=300),
                             window_end - timedelta(days=200))
            updated = rand_dt(rng, signed, window_end)

        # Customer lifetime: ~35% churn, the rest stay active to the end of the window.
        if rng.random() < 0.35:
            active_until = signed + timedelta(days=rng.randint(60, 500))
        else:
            active_until = window_end

        email_prefix = (first + "." + last).lower().replace("'", "").replace(" ", "")
        customers.append({
            "customer_id": cid,
            "email": "{}{}@example.com".format(email_prefix, cid),
            "first_name": first,
            "last_name": last,
            "country_code": country,
            "address_line_1": "{} {} {}".format(
                rng.randint(1, 9999),
                rng.choice(["Elm", "Oak", "Maple", "Cedar", "Pine"]),
                rng.choice(["St", "Ave", "Rd", "Blvd", "Ln"]),
            ),
            "city": city,
            "postal_code": str(rng.randint(10000, 99999)),
            "signed_up_at": ts(signed),
            "updated_at": ts(updated),
            "loaded_at": ts(ingest(rng, updated)),
            # generation-time only; not emitted (DictWriter ignores extras)
            "_signed": signed,
            "_active_until": active_until,
        })

    # Guarantee the tail of the customers feed sits at the very end of the window, so
    # `source freshness` on raw_ecom.customers passes for the whole runway instead of
    # depending on where the uniform draw happened to land.
    tail_pool = [c for c in customers if c["customer_id"] not in DEMO_CUSTOMER_IDS]
    for cust in rng.sample(tail_pool, k=min(5, len(tail_pool))):
        updated = rand_dt(rng, window_end - timedelta(days=1), window_end)
        cust["updated_at"] = ts(updated)
        cust["loaded_at"] = ts(ingest(rng, updated))

    # --- products ---
    # Every product exists before the order window opens, so no order_item can
    # reference a product that had not been created yet.
    products = []
    for pid in range(1, args.products + 1):
        cat_id, cat_name = rng.choice(PRODUCT_CATEGORIES)
        adj = rng.choice(PRODUCT_ADJECTIVES)
        noun = rng.choice(PRODUCT_NOUNS[cat_id])
        created = rand_dt(rng, window_start - timedelta(days=400),
                          window_start - timedelta(days=30))
        updated = rand_dt(rng, created, window_end)
        price_cents = rng.choice([1999, 2499, 2999, 3499, 3999, 4999, 5999, 6999, 8999, 11999])
        products.append({
            "product_id": pid,
            "sku": "{}-{:04d}".format(cat_name.upper()[:3], pid),
            "name": "{} {}".format(adj, noun),
            "category_id": cat_id,
            "price_cents": price_cents,
            "is_active": rng.random() > 0.1,
            "created_at": ts(created),
            "updated_at": ts(updated),
            "loaded_at": ts(ingest(rng, updated)),
        })
    for prod in rng.sample(products, k=min(3, len(products))):
        updated = rand_dt(rng, window_end - timedelta(days=1), window_end)
        prod["updated_at"] = ts(updated)
        prod["loaded_at"] = ts(ingest(rng, updated))

    # --- orders ---
    # Built day-by-day off a per-day allocation rather than by sampling a datetime
    # range, which is what makes the density guarantee hold by construction.
    per_day = spread(rng, args.orders, MIN_ORDERS_PER_DAY, days)
    raw_orders = []
    for day in days:
        eligible = [c for c in customers
                    if c["_signed"].date() <= day <= c["_active_until"].date()]
        if not eligible:
            eligible = [c for c in customers if c["_signed"].date() <= day]
        if not eligible:
            eligible = customers
        for _ in range(per_day[day]):
            customer = rng.choice(eligible)
            created = rand_dt_on_day(rng, day)
            if created < customer["_signed"]:
                created = customer["_signed"] + timedelta(seconds=60)
            updated = rand_dt(rng, created, min(created + timedelta(days=30), window_end))
            raw_orders.append({
                "customer_id": customer["customer_id"],
                "status": rng.choices(STATUSES, weights=STATUS_WEIGHTS, k=1)[0],
                "currency": CURRENCY_BY_COUNTRY.get(customer["country_code"], "USD"),
                "_created": created,
                "_updated": updated,
            })

    # Chronological order_id. Keeping the surrogate key monotonic in event time is what
    # lets the append-strategy demos use `id > max(id)` as a watermark.
    raw_orders.sort(key=lambda o: o["_created"])
    orders = []
    for oid, o in enumerate(raw_orders, start=1):
        orders.append({
            "order_id": oid,
            "customer_id": o["customer_id"],
            "status": o["status"],
            "order_total_cents": 0,  # filled in once order_items exist
            "currency": o["currency"],
            "created_at": ts(o["_created"]),
            "updated_at": ts(o["_updated"]),
            "loaded_at": ts(ingest(rng, o["_updated"])),
            "_created": o["_created"],
        })

    # --- order_items ---
    order_items = []
    for order in orders:
        n_lines = min(max(1, int(rng.gauss(AVG_ITEMS_PER_ORDER, 1.5))), 8)
        chosen = rng.sample(products, k=n_lines)
        total = 0
        for line_no, prod in enumerate(chosen, start=1):
            qty = rng.randint(1, 4)
            unit = prod["price_cents"]
            total += qty * unit
            order_items.append({
                "order_id": order["order_id"],
                "line_no": line_no,
                "product_id": prod["product_id"],
                "quantity": qty,
                "unit_price_cents": unit,
                # An order's lines land with the order.
                "loaded_at": order["loaded_at"],
            })
        order["order_total_cents"] = total

    # --- audit_events ---
    orders_by_day = {}
    for order in orders:
        orders_by_day.setdefault(order["_created"].date(), []).append(order["order_id"])
    cumulative = []
    eligible_by_day = {}
    for day in days:
        cumulative.extend(orders_by_day.get(day, []))
        # An audit event points at a recent order. Capping the candidate pool keeps
        # this loop linear instead of copying a growing prefix 1300+ times.
        eligible_by_day[day] = cumulative[-400:]

    audit_per_day = spread(rng, args.audit_events, MIN_AUDIT_EVENTS_PER_DAY, days)
    actions = ["created", "updated", "status_changed", "refunded"]
    raw_events = []
    for day in days:
        pool = eligible_by_day[day]
        for _ in range(audit_per_day[day]):
            raw_events.append({
                "entity": "order",
                "entity_id": rng.choice(pool),
                "action": rng.choice(actions),
                "_occurred": rand_dt_on_day(rng, day),
            })
    raw_events.sort(key=lambda e: e["_occurred"])
    audit_events = []
    for eid, e in enumerate(raw_events, start=1):
        audit_events.append({
            "event_id": eid,
            "entity": e["entity"],
            "entity_id": e["entity_id"],
            "action": e["action"],
            "occurred_at": ts(e["_occurred"]),
            "loaded_at": ts(ingest(rng, e["_occurred"])),
            "_occurred": e["_occurred"],
        })

    # --- currency_rates ---
    # One row per currency: models/sources.yml asserts `unique` on currency_code and
    # fct_orders joins on it alone, so this table is a current-rate lookup, not a rate
    # history. `rate_as_of` is the end of the generated window -- the honest reading of
    # "this single rate is the one in force for every day the fixture covers".
    rate_as_of = window_end.date()
    currency_rates = [
        {
            "currency_code": code,
            "usd_per_unit": USD_PER_UNIT[code],
            "rate_as_of": rate_as_of.isoformat(),
            "loaded_at": ts(ingest(rng, window_end)),
        }
        for code in ("USD", "EUR", "GBP", "CAD", "AUD")
    ]

    return {
        "anchor": anchor,
        "window_start": window_start,
        "window_end": window_end,
        "days": days,
        "customers": customers,
        "products": products,
        "orders": orders,
        "order_items": order_items,
        "audit_events": audit_events,
        "currency_rates": currency_rates,
    }


# --- self-check -----------------------------------------------------------------
class FixtureCheckError(AssertionError):
    """Raised when the generated fixture violates a guarantee this project depends on."""


def check(data: dict) -> list:
    """Assert every property the project's relative-time models rely on.

    Fails loudly rather than writing a fixture that would silently produce empty
    models and vacuously-passing tests.
    """
    problems = []
    anchor = data["anchor"]
    days = data["days"]

    orders = data["orders"]
    events = data["audit_events"]

    # 1. every calendar day in the window carries at least one order
    order_days = set(o["_created"].date() for o in orders)
    missing_order_days = [d for d in days if d not in order_days]
    if missing_order_days:
        problems.append("{} day(s) have no orders, first = {}".format(
            len(missing_order_days), missing_order_days[0]))

    # 2. every 3-day window carries at least one order (what `--sample '3 days'` needs)
    have = [1 if d in order_days else 0 for d in days]
    empty_windows = [days[i] for i in range(len(days) - 2)
                     if not (have[i] or have[i + 1] or have[i + 2])]
    if empty_windows:
        problems.append("{} empty 3-day window(s), first starts {}".format(
            len(empty_windows), empty_windows[0]))

    # 3. every calendar day carries at least one audit event
    event_days = set(e["_occurred"].date() for e in events)
    missing_event_days = [d for d in days if d not in event_days]
    if missing_event_days:
        problems.append("{} day(s) have no audit events, first = {}".format(
            len(missing_event_days), missing_event_days[0]))

    # 4. two years of forward freshness runway on every table that declares freshness
    #    (raw_ecom.audit_events sets `freshness: null`, so it is exempt).
    runway = anchor + timedelta(days=730)
    for name in ("customers", "products", "orders", "order_items", "currency_rates"):
        newest = max(_parse(r["loaded_at"]) for r in data[name])
        if newest < runway:
            problems.append(
                "{}: newest loaded_at {:%Y-%m-%d} is inside the 2-year runway "
                "(needs >= {:%Y-%m-%d}) -- source freshness would go stale".format(
                    name, newest, runway))

    # 5. both sides of "now" are populated: past orders for the marts, future orders
    #    for the scheduled-order teaching point.
    past = sum(1 for o in orders if o["_created"] <= anchor)
    future = len(orders) - past
    if not past or not future:
        problems.append("expected orders on both sides of the anchor, got {} past / {} future"
                        .format(past, future))

    # 6. the two dev-mode relative windows resolve to something
    last7 = sum(1 for o in orders if anchor - timedelta(days=7) <= o["_created"] <= anchor)
    last30 = sum(1 for e in events if anchor - timedelta(days=30) <= e["_occurred"] <= anchor)
    if last7 < 5:
        problems.append("only {} order(s) in the 7 days before the anchor "
                        "(mv_recent_orders would be near-empty)".format(last7))
    if last30 < 20:
        problems.append("only {} audit event(s) in the 30 days before the anchor "
                        "(limit_data_in_dev window)".format(last30))

    # 7. arithmetic and referential integrity
    items_by_order = {}
    for it in data["order_items"]:
        items_by_order[it["order_id"]] = (items_by_order.get(it["order_id"], 0)
                                          + it["quantity"] * it["unit_price_cents"])
    mismatched = [o["order_id"] for o in orders
                  if items_by_order.get(o["order_id"]) != o["order_total_cents"]]
    if mismatched:
        problems.append("{} order(s) whose total != sum of line items".format(len(mismatched)))

    customer_ids = set(c["customer_id"] for c in data["customers"])
    product_ids = set(p["product_id"] for p in data["products"])
    order_ids = set(o["order_id"] for o in orders)
    if not all(o["customer_id"] in customer_ids for o in orders):
        problems.append("orders reference a customer_id that does not exist")
    if not all(i["product_id"] in product_ids for i in data["order_items"]):
        problems.append("order_items reference a product_id that does not exist")
    if not all(i["order_id"] in order_ids for i in data["order_items"]):
        problems.append("order_items reference an order_id that does not exist")
    if not all(e["entity_id"] in order_ids for e in events):
        problems.append("audit_events reference an order_id that does not exist")

    # 8. an order never predates its customer's signup
    signed = dict((c["customer_id"], c["_signed"]) for c in data["customers"])
    early = [o["order_id"] for o in orders if o["_created"] < signed[o["customer_id"]]]
    if early:
        problems.append("{} order(s) predate the customer's signed_up_at".format(len(early)))

    # 9. demo customers stay in the past (scripts/mutate-customers.sql writes now())
    for cust in data["customers"]:
        if cust["customer_id"] in DEMO_CUSTOMER_IDS and _parse(cust["updated_at"]) >= anchor:
            problems.append(
                "demo customer {} has a forward-dated updated_at; "
                "scripts/mutate-customers.sql would no longer trigger a new snapshot "
                "version".format(cust["customer_id"]))
            break

    # 10. nothing escaped the declared window
    if order_days and (min(order_days) < days[0] or max(order_days) > days[-1]):
        problems.append("orders fall outside the declared window")

    return problems


# --- main -----------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--anchor", type=date.fromisoformat,
                    default=datetime.now(timezone.utc).date(),
                    help="ISO date the whole fixture is generated relative to "
                         "(default: today, UTC).")
    ap.add_argument("--back-days", type=int, default=BACK_DAYS)
    ap.add_argument("--forward-days", type=int, default=FORWARD_DAYS)
    ap.add_argument("--customers", type=int, default=NUM_CUSTOMERS)
    ap.add_argument("--products", type=int, default=NUM_PRODUCTS)
    ap.add_argument("--orders", type=int, default=NUM_ORDERS)
    ap.add_argument("--audit-events", type=int, default=NUM_AUDIT_EVENTS)
    ap.add_argument("--seed", type=int, default=SEED)
    ap.add_argument("--out-dir", type=Path, default=OUT_DIR_DEFAULT)
    args = ap.parse_args()

    data = build(args)

    problems = check(data)
    if problems:
        raise FixtureCheckError(
            "generated fixture failed its self-check; nothing written:\n  - "
            + "\n  - ".join(problems)
        )

    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    _write_csv(out_dir, "customers.csv", data["customers"], [
        "customer_id", "email", "first_name", "last_name", "country_code",
        "address_line_1", "city", "postal_code", "signed_up_at", "updated_at", "loaded_at",
    ])
    _write_csv(out_dir, "products.csv", data["products"], [
        "product_id", "sku", "name", "category_id", "price_cents",
        "is_active", "created_at", "updated_at", "loaded_at",
    ])
    _write_csv(out_dir, "orders.csv", data["orders"], [
        "order_id", "customer_id", "status", "order_total_cents", "currency",
        "created_at", "updated_at", "loaded_at",
    ])
    _write_csv(out_dir, "order_items.csv", data["order_items"], [
        "order_id", "line_no", "product_id", "quantity", "unit_price_cents", "loaded_at",
    ])
    _write_csv(out_dir, "audit_events.csv", data["audit_events"], [
        "event_id", "entity", "entity_id", "action", "occurred_at", "loaded_at",
    ])
    _write_csv(out_dir, "currency_rates.csv", data["currency_rates"], [
        "currency_code", "usd_per_unit", "rate_as_of", "loaded_at",
    ])

    anchor = data["anchor"]
    orders = data["orders"]
    events = data["audit_events"]
    day_orders = {}
    for o in orders:
        day_orders[o["_created"].date()] = day_orders.get(o["_created"].date(), 0) + 1
    day_events = {}
    for e in events:
        day_events[e["_occurred"].date()] = day_events.get(e["_occurred"].date(), 0) + 1
    past = sum(1 for o in orders if o["_created"] <= anchor)

    print("anchor            {:%Y-%m-%d}".format(anchor))
    print("business window   {:%Y-%m-%d} .. {:%Y-%m-%d}  ({} days)".format(
        data["window_start"], data["window_end"], len(data["days"])))
    print("newest loaded_at  {:%Y-%m-%d %H:%M:%S} (orders)  /  {:%Y-%m-%d %H:%M:%S} (customers)".format(
        max(_parse(r["loaded_at"]) for r in orders),
        max(_parse(r["loaded_at"]) for r in data["customers"])))
    print("rows              customers={} products={} orders={} order_items={} "
          "audit_events={} currency_rates={}".format(
              len(data["customers"]), len(data["products"]), len(orders),
              len(data["order_items"]), len(events), len(data["currency_rates"])))
    print("orders vs anchor  {} on/before, {} after (scheduled / pre-orders)".format(
        past, len(orders) - past))
    print("density           orders/day min={} avg={:.2f}   audit_events/day min={} avg={:.2f}".format(
        min(day_orders.values()), len(orders) / len(data["days"]),
        min(day_events.values()), len(events) / len(data["days"])))
    print("self-check        OK -- every day has orders, every day has audit events, "
          "2-year freshness runway intact")
    print("wrote 6 CSVs to   {}".format(out_dir))


if __name__ == "__main__":
    main()
