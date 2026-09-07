{#
    The `exceptions` namespace, all four documented functions, in one callable macro.

    Nothing else in this project raises deliberately, so without a fixture the namespace is
    read-about-only. It is a MACRO rather than a model on purpose: macros are not selectable
    nodes, so this file adds nothing to `dbt build` and the green line is unchanged.

    Every call is wrapped in `{% if execute %}`. During dbt's parse pass `execute` is false and
    the block is skipped; without the guard an unconditional raise would fire at parse time and
    break every command, including `dbt parse` itself. That guard is the assessed half of this
    topic as often as the function names are.

    Every outcome below was observed against dbt-core 1.11.14 / dbt-postgres 1.11.0, not
    inferred from the docs.

        dbt run-operation demo_exceptions --args '{kind: warn}'
            -> the message prints on its own line and the macro KEEPS GOING (the second log
               line proves it). Exit 0. Note what is not there: at 1.11.14 a
               `exceptions.warn()` line carries no `[WARNING]` prefix, so do not grep for one.

        dbt --warn-error-options '{"error": ["JinjaLogWarning"]}' \
            run-operation demo_exceptions --args '{kind: warn}'
            -> `Encountered an error while running operation: Compilation Error in macro
               demo_exceptions`, exit 1. That is the escalation half: `exceptions.warn()`
               raises a `JinjaLogWarning`, and naming that event under `--warn-error-options`
               turns it into a failure. This is the ONLY one of the four that is escalatable.

               Use the granular form, not bare `--warn-error`, to see it. Bare `--warn-error`
               does exit 2 here, but on the project's own standing deprecation advisory about
               `dim_customer_segments.v1` -- it never reaches this macro, so it demonstrates
               the blunt lever rather than this warning.

        dbt run-operation demo_exceptions --args '{kind: compiler_error}'
            -> `Encountered an error while running operation: Compilation Error in macro
               demo_exceptions`, exit 1. Nothing after the raise runs.

        dbt run-operation demo_exceptions --args '{kind: fail_fast}'
            -> `FailFast Error in macro demo_exceptions`, exit 1. The execution-time sibling:
               it is the class dbt itself raises under `--fail-fast`, not a compile complaint.

        dbt run-operation demo_exceptions --args '{kind: not_implemented}'
            -> `Encountered an error while running operation: Runtime Error` followed by
               `ERROR: <msg>`, exit 1. Note the class: at 1.11.14 this one surfaces as a
               RUNTIME error, not a Compilation Error, and the message is prefixed `ERROR: `.
               This is the function an ADAPTER or PACKAGE author raises from a `default__`
               implementation to mean "override me"; see macros/date_trunc_day.sql for the
               dispatch pattern it belongs to.

    An unrecognised `kind` is itself a `raise_compiler_error` (exit 1), so a typo fails loudly
    rather than silently doing nothing.
#}
{% macro demo_exceptions(kind='warn') %}

    {% if execute %}

        {% if kind == 'warn' %}
            {% do exceptions.warn(
                "demo_exceptions: compile-time warning. The run continues and the caller still "
                ~ "succeeds; --warn-error-options '{\"error\": [\"JinjaLogWarning\"]}' turns it "
                ~ "into a failure."
            ) %}
            {{ log("demo_exceptions: still running after the warning -- that is the point.", info=True) }}

        {% elif kind == 'compiler_error' %}
            {% do exceptions.raise_compiler_error(
                "demo_exceptions: compile-time failure. Nothing after this point runs."
            ) %}

        {% elif kind == 'fail_fast' %}
            {% do exceptions.raise_fail_fast_error(
                "demo_exceptions: execution-time fail-fast. The same class dbt raises for --fail-fast."
            ) %}

        {% elif kind == 'not_implemented' %}
            {% do exceptions.raise_not_implemented(
                "demo_exceptions: adapter/package authors raise this from a default__ implementation"
            ) %}

        {% else %}
            {% do exceptions.raise_compiler_error(
                "demo_exceptions: unknown kind '" ~ kind ~ "'. "
                ~ "Expected one of: warn, compiler_error, fail_fast, not_implemented."
            ) %}
        {% endif %}

    {% endif %}

{% endmacro %}
