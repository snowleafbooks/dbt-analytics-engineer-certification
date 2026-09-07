{# depends_on: {{ ref('dc_upstream') }} #}
{#
   A JINJA comment. Jinja strips this block without rendering what is inside, so the ref call
   above never runs and no edge is registered. In a diff this file is one character different
   from its sibling, and it does nothing at all.
#}
select * from {{ target.schema }}.dc_upstream
