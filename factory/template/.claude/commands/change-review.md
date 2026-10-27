---
description: Review a lane's change before it lands, using the read-only reviewer agent.
argument-hint: [branch or lane name; default the current branch]
---
<!-- Factory-managed (see .factory-version). -->
Review target: $ARGUMENTS (empty means the current branch)

1. Gather what the reviewer needs: the branch, its base, the brief or plan, and the file scope.
   For a T2/T3 change also dispatch the `critic` on the design.
2. For a worktree lane, run `/lane-review <lane>` (0.4.0): it audits the lane's scope
   (`scripts/lane audit <lane> --reported <file>`), runs the base-vs-lane test gate, the mutants,
   `julia scripts/ci.jl guards` and `julia scripts/dod.jl --base <base>`, dispatches the
   `reviewer` (read-only) with the report protocol, and audits the report with
   `scripts/lane audit <lane> --report <file>`. For a plain branch, dispatch the `reviewer`
   yourself with the same inputs; it runs and pastes
   `git diff --stat $(git merge-base HEAD main)..HEAD`, `julia scripts/dod.jl --base main`
   and `julia scripts/ci.jl guards`. A lane created without `--owns` fails the audit: pass
   `--owns` to audit.
3. Wait for the reviewer's FINAL report. A preview is not a verdict; a report file whose first
   line is not the Verdict line is partial.
4. Check the findings yourself before acting on them: each needs file:line and evidence.
   Every blocker carries a `Reproducer:` command; it is closed only when the reviewer quotes that
   command RED before the fix and GREEN after. Same for a cross-repo request.
5. Output: the verdict (`Verdict: MAY MERGE | MERGE WITH FIXES | FIX FIRST`, one of the three,
   with its `Head: <sha>`), findings by severity (each with its Reproducer and its red/green
   runs), DoD result, the lane audits, and which checks did not run and why (a
   `NOT RUN (waiting)` CI job did not run). Close the reviewer agent once its report is read.
