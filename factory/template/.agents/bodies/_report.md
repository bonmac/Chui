## Report (one protocol for every agent)

- Write findings to `<session root>/.lanes/reports/<name>.md`, an absolute path whose root is the session
  root the brief names (a later round: `<name>--r<round>.md`, a double dash and `r`), with the Write tool
  as they are confirmed, where `<name>` is exactly your dispatch name (`teammate_name` /
  `tool_input.name`; the brief names it). The file counts once its first line is final.
- Line 1 of a write agent's report: `Status: DONE | PARTIAL | BLOCKED` (exactly one, exact case, no
  formatting). While writing, line 1 is `Status: PARTIAL` (the file is then not yet a report); replace
  it last. A read-only agent's line 1 is the Verdict line (its own section below), never a Status.
- A test-side role (test-writer, law-, property-, differential-tester) writes its report ONCE, at the end,
  with its final line 1: the Write tool needs a prior Read to overwrite a file, and a test-side role may
  not Read reports, so the `Status: PARTIAL` draft above does not apply to it.
- The TDD roles (test-writer, law-, property-, differential-tester, implementer) are dispatched unnamed
  (0.3.1): their final reply is the report, and the report file above is optional for them. Every
  other agent is dispatched named and writes the file.
- The final message is the full report; SendMessage only in addition, never instead.
- At most 80 lines. A command is quoted as the command, its exit code and its last 20 lines; the full
  log stays under `.lanes/evidence/`. Say which checks did NOT run, and why.
