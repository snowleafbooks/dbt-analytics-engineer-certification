-- A perfectly ordinary model. Nothing is wrong with this file.
-- It is here only so the sibling has something real to point at, and so you can watch dbt
-- decline to build it first -- because nothing tells dbt it is a parent.
select 1 as order_id, 4999 as amount_cents
