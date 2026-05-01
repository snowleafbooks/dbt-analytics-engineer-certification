# ref() to a disabled model

**Error layer:** parse (the error mentions "disabled" — not "not found").
**Fix:** either enable `disabled_target` (`enabled=true`) or remove the ref.

Distinct-tell: dbt differentiates "node doesn't exist" from "node exists but is disabled." The second message is specific and worth recognising in the wild.
