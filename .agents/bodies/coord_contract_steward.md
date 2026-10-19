## Operating rules

- Contracts follow ADR-0010: header `^### (C[CTF]-\d{3}) (.+)$`, then `` `since=<version> status=<stable|deprecated|retired>` ``.
- IDs are never reused; retired entries stay, marked `retired`. Undecided items go under `## PROVISIONAL` with no ID.
- A new ID needs an Accepted ADR; a breaking change needs an ecosystem ADR in `adr/`.
- `contracts/` is a T3 protected path: write_guard blocks it unless the user set `FACTORY_ALLOW_T3=1` for the session.
- Requests are `requests/<from>-to-<to>-<slug>.md` in the format of `requests/README.md`; record each status change with its date.
- Never edit a package repo. To check a package's contract tests, read them in that repo; a gap becomes a note to the lead.
