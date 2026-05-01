#!/usr/bin/env python3
"""
Regenerate the data-seed/ CSVs with a fixed random seed.
Stdlib-only; run from repo root:  python scripts/generate_data.py
"""
from __future__ import annotations

import csv
import os
import random
from datetime import datetime, timedelta
from pathlib import Path

SEED = 20240101
NUM_CUSTOMERS = 200
NUM_PRODUCTS = 50
NUM_ORDERS = 1000
AVG_ITEMS_PER_ORDER = 3
NUM_AUDIT_EVENTS = 500

OUT_DIR = Path(__file__).resolve().parent.parent / "data-seed"
OUT_DIR.mkdir(parents=True, exist_ok=True)

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
PRODUCT_ADJECTIVES = ["Classic", "Modern", "Eco", "Pro", "Lite", "Heritage", "Everyday", "Alpine", "Coastal", "Urban"]
PRODUCT_NOUNS = {
    1: ["Tee", "Hoodie", "Jacket", "Sweater", "Pants"],
    2: ["Sneaker", "Boot", "Runner", "Slip-On", "Sandal"],
    3: ["Bag", "Cap", "Belt", "Wallet", "Scarf"],
    4: ["Mug", "Blanket", "Lamp", "Candle", "Pillow"],
    5: ["Headphones", "Charger", "Speaker", "Cable", "Webcam"],
    6: ["Tent", "Daypack", "Bottle", "Stove", "Mat"],
}

EPOCH = datetime(2024, 1, 1)
NOW = datetime(2025, 6, 1)
LOADED_AT = datetime(2025, 6, 1, 3, 30)


def ts(d: datetime) -> str:
    return d.strftime("%Y-%m-%d %H:%M:%S")


def rand_dt(rng: random.Random, start: datetime, end: datetime) -> datetime:
    delta = int((end - start).total_seconds())
    return start + timedelta(seconds=rng.randint(0, delta))


def main() -> None:
    rng = random.Random(SEED)

    # --- customers ---
    customers = []
    for cid in range(1, NUM_CUSTOMERS + 1):
        country = rng.choice(COUNTRIES)
        city = rng.choice(COUNTRY_CITIES[country])
        first = rng.choice(FIRST_NAMES)
        last = rng.choice(LAST_NAMES)
        signed = rand_dt(rng, EPOCH, NOW - timedelta(days=1))
        updated = rand_dt(rng, signed, NOW)
        email_prefix = (first + "." + last).lower().replace("'", "").replace(" ", "")
        customers.append({
            "customer_id": cid,
            "email": f"{email_prefix}{cid}@example.com",
            "first_name": first,
            "last_name": last,
            "country_code": country,
            "address_line_1": f"{rng.randint(1, 9999)} {rng.choice(['Elm','Oak','Maple','Cedar','Pine'])} {rng.choice(['St','Ave','Rd','Blvd','Ln'])}",
            "city": city,
            "postal_code": f"{rng.randint(10000, 99999)}",
            "signed_up_at": ts(signed),
            "updated_at": ts(updated),
            "loaded_at": ts(LOADED_AT),
        })

    # --- products ---
    products = []
    for pid in range(1, NUM_PRODUCTS + 1):
        cat_id, cat_name = rng.choice(PRODUCT_CATEGORIES)
        adj = rng.choice(PRODUCT_ADJECTIVES)
        noun = rng.choice(PRODUCT_NOUNS[cat_id])
        created = rand_dt(rng, EPOCH, NOW - timedelta(days=30))
        updated = rand_dt(rng, created, NOW)
        price_cents = rng.choice([1999, 2499, 2999, 3499, 3999, 4999, 5999, 6999, 8999, 11999])
        products.append({
            "product_id": pid,
            "sku": f"{cat_name.upper()[:3]}-{pid:04d}",
            "name": f"{adj} {noun}",
            "category_id": cat_id,
            "price_cents": price_cents,
            "is_active": rng.random() > 0.1,
            "created_at": ts(created),
            "updated_at": ts(updated),
            "loaded_at": ts(LOADED_AT),
        })

    # --- orders ---
    orders = []
    for oid in range(1, NUM_ORDERS + 1):
        customer = rng.choice(customers)
        created = rand_dt(rng, EPOCH, NOW)
        updated = rand_dt(rng, created, min(created + timedelta(days=30), NOW))
        status = rng.choices(STATUSES, weights=STATUS_WEIGHTS, k=1)[0]
        currency = CURRENCY_BY_COUNTRY.get(customer["country_code"], "USD")
        orders.append({
            "order_id": oid,
            "customer_id": customer["customer_id"],
            "status": status,
            "order_total_cents": 0,  # filled after order_items
            "currency": currency,
            "created_at": ts(created),
            "updated_at": ts(updated),
            "loaded_at": ts(LOADED_AT),
        })

    # --- order_items ---
    order_items = []
    for order in orders:
        n_lines = max(1, int(rng.gauss(AVG_ITEMS_PER_ORDER, 1.5)))
        n_lines = min(n_lines, 8)
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
                "loaded_at": ts(LOADED_AT),
            })
        order["order_total_cents"] = total

    # --- audit_events ---
    audit_events = []
    actions = ["created", "updated", "status_changed", "refunded"]
    for eid in range(1, NUM_AUDIT_EVENTS + 1):
        order = rng.choice(orders)
        occurred = rand_dt(rng, EPOCH, NOW)
        audit_events.append({
            "event_id": eid,
            "entity": "order",
            "entity_id": order["order_id"],
            "action": rng.choice(actions),
            "occurred_at": ts(occurred),
            "loaded_at": ts(LOADED_AT),
        })

    _write_csv("customers.csv", customers, [
        "customer_id", "email", "first_name", "last_name", "country_code",
        "address_line_1", "city", "postal_code", "signed_up_at", "updated_at", "loaded_at",
    ])
    _write_csv("products.csv", products, [
        "product_id", "sku", "name", "category_id", "price_cents",
        "is_active", "created_at", "updated_at", "loaded_at",
    ])
    _write_csv("orders.csv", orders, [
        "order_id", "customer_id", "status", "order_total_cents", "currency",
        "created_at", "updated_at", "loaded_at",
    ])
    _write_csv("order_items.csv", order_items, [
        "order_id", "line_no", "product_id", "quantity", "unit_price_cents", "loaded_at",
    ])
    _write_csv("audit_events.csv", audit_events, [
        "event_id", "entity", "entity_id", "action", "occurred_at", "loaded_at",
    ])

    print(f"Wrote 5 CSVs to {OUT_DIR}")


def _write_csv(name: str, rows, fieldnames):
    path = OUT_DIR / name
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)


if __name__ == "__main__":
    main()
