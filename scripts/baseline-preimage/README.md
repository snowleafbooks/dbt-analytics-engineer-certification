# The baseline preimage

> Lives in `scripts/` and not in `prior-artifacts/` because `.gitignore` excludes
> `prior-artifacts/` entirely. The four JSON artifacts are build output and are regenerated in
> seconds; **this preimage is source**, and has to survive a clone.

`prior-artifacts/` holds the four dbt artifacts (`manifest.json`, `run_results.json`,
`sources.json`, `catalog.json`) that every `state:`, `--defer`, `result:` and
`source_status:` demo in this repo diffs against. It is **gitignored build output** (`.gitignore:4`),
so a fresh clone never receives it and `bash scripts/save-baseline.sh --rebase` has to generate it.
This directory is the part that *is* committed, and it is what makes that regeneration reproducible.

A baseline is only useful if it *differs* from the working project. A baseline saved from
HEAD makes `state:modified` select nothing, `slim-ci.sh` build nothing, and the whole slim-CI
lesson vacuous. So the baseline here is built from a deliberately **earlier** project state,
described by `PREIMAGE` in this directory (`scripts/baseline-preimage/`), and the difference between that state and HEAD is
a small, realistic pull request:

| The "PR" HEAD represents | Mechanism | What it makes selectable |
|---|---|---|
| `stg_products` stops doing its own cents→dollars arithmetic and calls the shared `cents_to_dollars()` macro | `replace models/staging/stg_products.sql` | `state:modified` / `state:modified.body` on `stg_products`, and a 15-node descendant subtree (`dim_products`, the ephemeral `int_order_items_enriched`, `fct_order_items`, and their tests) |
| a new singular test, `assert_large_orders_within_review_tolerance`, lands on `fct_orders` | `remove tests/assert_large_orders_within_review_tolerance.sql` | `state:new` — and, under `--defer`, a test that runs against the **deferred** `fct_orders` without rebuilding it |

Everything else is `state:unmodified`.

The refactor is deliberately **value-neutral**: `round(cast(price_cents as numeric) / 100.0, 2)`
and `cents_to_dollars('price_cents')` compile to the same expression, so the baseline
relations in `dev` are identical to what HEAD produces. That is what makes `--defer` safe to
demonstrate here, and it is also the realistic case — the refactor you *believe* is
value-neutral is exactly the one CI exists to check.

## Rebuilding the baseline

```bash
bash scripts/save-baseline.sh --rebase
```

That stages the preimage, runs `dbt build` → `dbt source freshness` → `dbt docs generate`,
copies each artifact out **immediately after the command that produces it**, and restores
your working tree (via a `trap`, so an interrupt restores it too). Nothing is left dirty.

## Maintaining it

If you edit `models/staging/stg_products.sql` or delete/rename the singular test, `--rebase`
will **abort** with a hash mismatch. That is intended. Re-derive the preimage by hand:

1. copy the new HEAD file into `scripts/baseline-preimage/files/<same path>`,
2. re-apply the "before" edit to that copy,
3. update the sha256 in `PREIMAGE` (`sha256sum <path>`).

Keep the preimage surface small. Every file listed in `PREIMAGE` is a file that has to be
kept in step with HEAD forever.
