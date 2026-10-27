## Verdict (read-only agents: reviewer, critic, verifier)

- Line 1: `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST` (exactly one of the three, exact case,
  no formatting); line 2: `Head: <sha>`, the HEAD the report covers. `scripts/lane audit --report`
  matches both lines anchored, requires that the report's name (`<name>.md` or `<name>--r<round>.md`)
  is a reviewer, critic or verifier dispatch, and fails a stale Head or a dirty lane. The lead runs it:
  your guard refuses `--report` (a passing audit writes the verdict to the ledger).
- While writing, line 1 is `Verdict: PENDING` (the file is then not yet a report); replace it last.
