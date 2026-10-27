---
description: "Review a lane before it lands (0.4.0, D6): scope audit, base-vs-lane test gate, mutants, guards, then the read-only reviewer with the Verdict/Head report protocol."
argument-hint: <lane name> [round; default 1]
---
<!-- Factory-managed (see .factory-version). -->
Lane: $ARGUMENTS. Below, `<lane>` is its name (worktree `.worktrees/<lane>`), `<round>` the review
round (1, then +1 per re-review), `<base>` its recorded base, `<mb>` the merge base, `<sha>` its HEAD.

1. Pre-flight the pair and paste it:
   `git -C .worktrees/<lane> rev-parse --short HEAD` (`<sha>`),
   `git -C .worktrees/<lane> config branch.$(git -C .worktrees/<lane> branch --show-current).lane-base` (`<base>`),
   `git -C .worktrees/<lane> merge-base <base> HEAD` (`<mb>`).
   A base checkout for the comparison, gitignored inside the lane (`scripts/lane handoff` lists
   it as unmanaged; step 8 removes it):
   `git -C .worktrees/<lane> worktree add --detach .lanes/scratch/base-<mb> <mb>`.
2. Scope audit: `scripts/lane audit <lane> --reported <file>`, where the file is the changed-file
   list the lane reported (one path per line). A path outside its `--owns` globs, or a list that
   differs, is a finding for the reviewer (step 5), not a formality. Paste the output.
3. The test gate, by repo kind. Every run goes through `julia scripts/evidence.jl <kind> --root DIR -- <cmd>`,
   which runs `<cmd>` in DIR and writes `DIR/.lanes/evidence/<kind>-<sha7 of DIR's HEAD>.txt`
   (so the names are `base-<mb>` and `lane-<sha>`). Exit 124 is TIMED OUT, not a pass.
   - A `Project.toml` at the root (a package):
     `julia scripts/evidence.jl base --root .worktrees/<lane>/.lanes/scratch/base-<mb> -- julia scripts/ci.jl test --timeout 900`
     `julia scripts/evidence.jl lane --root .worktrees/<lane> -- julia scripts/ci.jl test --timeout 900`
     Then, when `scripts/tdd.jl` exists: `julia scripts/tdd.jl gaps --root .worktrees/<lane>`
     (public names with no test; Julia >= 1.11), and for each `@testitem` the diff adds
     (`git -C .worktrees/<lane> diff <mb>..HEAD -- test/`), one
     `julia scripts/tdd.jl mutate --root .worktrees/<lane> --item "<name>" --src <file>:<line> --from '<text>' --to '<mutant>'`
     against the code it covers. A mutant the item does not catch is a finding.
   - A `factory/MANIFEST.toml` at the root (the coordinator): the factory suite on both,
     `julia scripts/evidence.jl base --root .worktrees/<lane>/.lanes/scratch/base-<mb>/factory/template -- julia --startup-file=no scripts/test/runtests.jl`
     `julia scripts/evidence.jl lane --root .worktrees/<lane>/factory/template -- julia --startup-file=no scripts/test/runtests.jl`
     then the hook-mutation route (D3) for each changed hook: copy `.claude/hooks` into
     `.lanes/scratch/hooks-<n>`, change ONE thing in the copy with Write (drop a deny, invert a
     test), and run the hook tests against the copy with
     `(cd .worktrees/<lane>/factory/template && julia --startup-file=no scripts/test/runtests.jl gen hooks --hooks-dir .lanes/scratch/hooks-<n>)`
     (`gen` too: the hook tests use a helper of test_gen.jl). Paste the command, its exit code and
     its Test Summary. A mutant no test catches is a finding.
   - Neither file: print `test gate: NOT RUN (no Project.toml, no factory/MANIFEST.toml)`.
   Compare the two evidence files: `julia scripts/evidence.jl latest base --root <base checkout>`
   and `julia scripts/evidence.jl latest lane --root .worktrees/<lane>` print their paths;
   `evidence.jl` has no `diff` subcommand, so read each file's `exit:` and `tests:` headers
   (`tests: pass=N fail=N error=N broken=N total=N`, which `evidence.jl` derives from the run's
   Test Summary; the line is absent when the run printed none) and compare them yourself; paste
   both `tests:` lines, never a hand-parsed Test Summary. A run that printed
   `skipped (not applicable)` or `NOT RUN (waiting)`, or exited 124, is written `NOT RUN`,
   never as a green comparison. A base that already fails is said so; the lane is judged on the delta.
4. Guards and definition of done, in the lane:
   `(cd .worktrees/<lane> && julia scripts/ci.jl guards --timeout 900)` and
   `(cd .worktrees/<lane> && julia scripts/dod.jl --base <base>)`. Paste each command, its exit
   code and its last 20 lines.
5. Dispatch the `reviewer` agent (read-only; `subagent_type: reviewer`, the type the hooks
   enforce, never a general-purpose agent told to review) with a `name` (for example `<lane>-review`) and:
   the brief or plan, `<base>`, `<mb>`, `<sha>`, the file scope (the `--owns` globs), the step 2
   output, the evidence names `base-<mb>` and `lane-<sha>` (step 3) and the report path
   `.lanes/reports/<reviewer name>-<round>.md` (the dispatch name; `write_guard` allows it).
   Its report's line 1 is `Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST` (one of the
   three, exact case, nothing else on the line), line 2 `Head: <sha>`, at most 80 lines, each
   command quoted as command, exit code, last 20 lines. For a T2/T3 change also dispatch the
   `critic` on the design, same protocol, its own report file.
6. Wait for the FINAL report. A preview is not a verdict; a report file whose first line is not
   the Verdict line is partial. Check each finding yourself: file:line and evidence; every
   blocker carries a `Reproducer:` command, closed only when it is quoted RED before the fix and
   GREEN after.
7. `scripts/lane audit <lane> --report .lanes/reports/<reviewer name>-<round>.md` (the path
   where the reviewer wrote it: the lane worktree or the repo root). It fails on a missing or
   misspelled Verdict line, on a line 2 that is not `Head: <sha>`, on a `Head:` that is not the
   lane's current HEAD (a stale round: the lane moved after the review, so re-review with
   `<round>` + 1), on a dirty lane worktree, and on a report whose name is not a reviewer, critic
   or verifier dispatch of the ledger (an implementer's own `Status:` report is no review);
   passing, it records the verdict in the ledger (`scripts/lane stats` shows it).
8. Close the reviewer agent in the same step as reading its report (TaskStop, or let its call
   return; `scripts/lane release <name>` when it is already gone). The base checkout holds the
   base evidence file: `evidence.jl latest base` (step 3) printed its path RELATIVE to that
   root, so keep it BEFORE removing the checkout with
   `cp .worktrees/<lane>/.lanes/scratch/base-<mb>/<that path> .worktrees/<lane>/.lanes/evidence/`
   (for the coordinator, whose step 3 root is the subdirectory, insert `/factory/template`
   before `/<that path>`; the target is the lane's own evidence directory, next to
   `lane-<sha>.txt`; a plain copy, no redirect). Only then
   `git -C .worktrees/<lane> worktree remove .lanes/scratch/base-<mb>`.
9. Output: the Verdict and Head lines, both audits, base vs lane `tests:` lines quoted from the
   two evidence files now both under `.worktrees/<lane>/.lanes/evidence/` (`base-<mb>.txt` is the
   step 8 copy; or `NOT RUN` and why), the mutants run and caught, the guards and DoD lines, the
   findings by severity with their Reproducer and RED/GREEN runs, and every check that did not
   run and why.
