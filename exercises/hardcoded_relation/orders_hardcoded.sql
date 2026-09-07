-- The DAG-defeating line. Interpolating target.schema makes this LOOK careful -- it does
-- resolve to the right schema in every environment -- but it is string interpolation, not a
-- ref() call, so dbt records no edge and never learns hc_upstream has to be built first.
--
-- The fix is ref('hc_upstream'), in EVERY clause. A ref() in the FROM and a hardcoded name in
-- a JOIN leaves the join's parent exactly this invisible.
select * from {{ target.schema }}.hc_upstream
