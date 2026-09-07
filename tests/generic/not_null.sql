{#
    A ROOT-PROJECT GENERIC TEST NAMED AFTER A BUILT-IN. This file is the hazard, shipped live.

    dbt resolves a generic test by NAME, root project first. `not_null` is one of the four
    tests dbt-core ships, and the moment a `not_null` test block exists here it wins -- for
    every `not_null` in every properties file in the project, model tests and source tests
    alike. Nothing had to be edited to opt in. No YAML changed. No warning is emitted. The
    build stays green, which is precisely why this is worth shipping rather than describing:
    the failure mode of an accidental shadow is SILENCE.

    HOW MANY TESTS THIS FILE NOW OWNS. Every `not_null` call site in the project -- model
    tests and source tests both; REPO-COVERAGE.md section 5.1 carries the count. Measure it
    yourself, which is also how you would DETECT an accidental shadow in a project you
    inherited:

        dbt build
        grep -rl dbtae_companion__not_null_override target/compiled | wc -l

    Every one of those compiled test files carries the marker comment below. A built-in
    `not_null` would not.

    WHY IT DELEGATES INSTEAD OF REIMPLEMENTING. `{{ dbt.test_not_null(...) }}` hands the work
    straight back to dbt's own dispatched implementation, so the SQL, the `store_failures`
    column expansion (`select *` instead of `select <column>`), `where`, `limit`, `severity`
    and the compiled results are byte-for-byte what they were before this file existed. The
    node count and the `dbt build` summary line are unchanged. That is deliberate: the point
    of the fixture is the SHADOWING, not a behaviour change, and a repo whose `not_null` means
    something non-standard would mislead every other row in REPO-COVERAGE.md.

    A REAL accidental shadow does not delegate. Someone writes a `not_null` that also
    tolerates empty strings, or forgets `should_store_failures()`, and every one of those
    tests changes meaning at once, with no diff outside this one file. To see that, replace
    the delegation line with a body of your own and re-run `dbt build`.

    NOT THE SAME MECHANISM AS `adapter.dispatch`. Shadowing here is by macro NAME and package
    precedence. dbt's built-in `not_null` block is itself a thin wrapper that dispatches to
    `default__test_not_null`. Defining `postgres__test_not_null` in this project takes the
    dispatch route instead, and it reaches every one of the same tests through the built-in
    wrapper -- verified by execution on 2026-09-03, same marker count. Naming the test block
    itself, as here, replaces the wrapper outright, which is the broader hammer of the two.
#}
{% test not_null(model, column_name) %}
    /* dbtae_companion__not_null_override */
    {{ dbt.test_not_null(model, column_name) }}
{% endtest %}
