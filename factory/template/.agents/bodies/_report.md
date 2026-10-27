## Report (one protocol for every agent)

- Write findings to `.lanes/reports/<name>.md` (a later round: `<name>-<round>.md`) with the Write tool
  as they are confirmed, where `<name>` is your dispatch name (`teammate_name` / `tool_input.name`),
  else your agent type. The file counts as a report only once its first line is the Verdict line.
- Line 1: `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST` (exactly one of the three, exact case,
  no formatting); line 2: `Head: <sha>`, the HEAD the report covers.
- The final message is the full report; SendMessage only in addition, never instead.
- At most 80 lines. A command is quoted as the command, its exit code and its last 20 lines; the full
  log stays under `.lanes/evidence/`. Say which checks did NOT run, and why.
