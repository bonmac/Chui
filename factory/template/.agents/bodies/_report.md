## Report (one protocol for every agent)

- Write findings to `.lanes/reports/<name>.md` (a later round: `<name>--r<round>.md`, a double dash and
  `r`) with the Write tool as they are confirmed, where `<name>` is exactly your dispatch name
  (`teammate_name` / `tool_input.name`; the brief names it). The file counts once its first line is final.
- Line 1 of a write agent's report: `Status: DONE | PARTIAL | BLOCKED` (exactly one, exact case, no
  formatting). While writing, line 1 is `Status: PARTIAL` (the file is then not yet a report); replace
  it last. A read-only agent's line 1 is the Verdict line (its own section below), never a Status.
- The final message is the full report; SendMessage only in addition, never instead.
- At most 80 lines. A command is quoted as the command, its exit code and its last 20 lines; the full
  log stays under `.lanes/evidence/`. Say which checks did NOT run, and why.
