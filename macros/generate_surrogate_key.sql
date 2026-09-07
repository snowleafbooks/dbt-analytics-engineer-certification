{#
    Dispatch override of dbt_utils.generate_surrogate_key.

    THE NAME IS THE WHOLE MECHANISM. dbt_utils calls
    `adapter.dispatch('generate_surrogate_key', 'dbt_utils')`. For each package in the
    search order, dispatch looks for `<adapter>__<name>` and then `default__<name>` --
    here, `postgres__generate_surrogate_key` then `default__generate_surrogate_key`.
    It never looks for `<package>__<name>`. A macro named
    `dbtae_companion__generate_surrogate_key` is therefore dead code: it parses, it is
    callable by hand, and dispatch walks straight past it to dbt_utils' own
    `default__generate_surrogate_key`. Prove it either way by compiling stg_customers and
    reading the `coalesce(...)` sentinel -- `'_dbt_null_'` is ours, `'_dbt_utils_surrogate_key_null_'`
    is theirs.

    The search order comes from `dispatch:` in dbt_project.yml; see the note there about
    why that block is redundant for this particular override.

    The file used to be named after the dead macro. It is now named after the macro it
    actually defines -- macro file names carry no meaning to dbt, but they carry a lot to
    the next reader.

    Behavior difference from the dbt_utils default: this override lower-cases and trims
    every field before hashing, so casing / whitespace drift at source doesn't produce a
    new key. The primitive is still md5, but emitted directly rather than through
    `dbt.hash()` -- that indirection is the dbt_utils default's, not ours.
#}
{% macro default__generate_surrogate_key(field_list) %}
    {%- set fields = [] -%}
    {%- for field in field_list -%}
        {%- do fields.append(
            "coalesce(lower(trim(cast(" ~ field ~ " as " ~ dbt.type_string() ~ "))), '_dbt_null_')"
        ) -%}
    {%- endfor -%}

    md5(cast(concat({{ fields|join(", '-', ") }}) as varchar))
{% endmacro %}
