{#
  Demonstrates `enabled: false`. This model is discoverable by dbt parse but is
  excluded from the DAG, from docs, and from every `dbt build`: it is parked in
  `manifest['disabled']` rather than dropped, and `dbt ls --select _example_disabled`
  answers `No nodes selected!` exactly as it would for a name that does not exist.
  `.devcontainer/_verify_disabled.sh` asserts both halves.

  Nothing `ref()`s this model, so flipping `enabled` to true only builds it -- for what a
  downstream `ref()` to a disabled node does, see `exercises/ref_disabled/`, which stages
  the consumer and the disabled target together.
#}
{{ config(enabled=false) }}

select 1 as placeholder
