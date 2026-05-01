# access: private cross-group ref

**Error layer:** parse
**Fix:** either (a) move the consumer into group `pii` (appropriate for data-subject handling), or (b) relax the producer to `access: protected` (wrong for PII), or (c) create a masked public view in group `marketing` the consumer can ref instead.
