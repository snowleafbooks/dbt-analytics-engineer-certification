-- depends_on: {{ ref('dc_upstream') }}
--
-- A SQL comment. dbt renders the whole file as a Jinja template before any of it is SQL, so
-- the ref call on line 1 executes and registers the dependency; only afterwards does the SQL
-- parser throw the line away as a comment. The edge is real, the compiled query is unchanged.
select * from {{ target.schema }}.dc_upstream
