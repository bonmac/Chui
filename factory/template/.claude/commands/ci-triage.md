---
description: Triage a failed CI run (0.4.0, D6): group the failed jobs by first failing assertion, reproduce each locally with ci.jl, label flake | guard | defect.
argument-hint: [run id; default the newest failed run of the current branch]
allowed-tools: Bash(gh run:*), Bash(git:*), Bash(julia scripts/ci.jl:*), Bash(julia scripts/evidence.jl:*), Read, Grep
---
<!-- Factory-managed (see .factory-version). -->
Run: $ARGUMENTS (empty: the newest failed run from step 1)

1. `gh run list --limit 5` (add `--branch <branch>` for one branch) and pick the run `<id>`.
   Without `gh`, a remote or a login, print `ci-triage: NOT RUN (no gh)` and stop.
2. `gh run view <id>` (the job list and the commit) and `gh run view <id> --log-failed` (the
   failed steps' logs). Note the run's commit: `gh run view <id> --json headSha`.
3. Group the failed jobs. A job's key is its first line matching `Test Failed at`, else its
   first line matching `ERROR:`; jobs with the same key are one group. A job with neither (a
   cancelled job, a runner timeout, a job that printed `TIMED OUT`) is its own group, keyed
   `no assertion`. A job that printed `NOT RUN (waiting)` did not fail: list it as NOT RUN.
4. Reproduce each group once, locally, at the run's commit (a lane worktree already at it, or
   `git worktree add --detach .lanes/scratch/ci-<id> <sha>`), with the job's name as
   `julia scripts/ci.jl --list` prints it (the workflows call the same jobs):
   `julia scripts/ci.jl <job> --timeout 900`
   Paste the command, its exit code and its last 20 lines; exit 124 is TIMED OUT, not a pass.
   Keep the result: `julia scripts/evidence.jl ci-<job> --root <checkout> -- julia scripts/ci.jl <job> --timeout 900`.
5. Label each group:
   - `flake`: passes locally at the same commit, and the log shows time, network or runner
     limits (a timeout, a download, a rate limit, a busy benchmark runner). Propose a re-run
     (`gh run rerun <id> --failed`) to the user; do not re-run it yourself.
   - `guard`: a gate said no (`ci.jl guards`, ratchets, check_docs, check_claims, dod, a format
     diff, a `FAILED (missing)` skip): the change is fixed in the gate's own terms, never by
     loosening the gate.
   - `defect`: fails locally the same way. Say whether the base commit also fails
     (`julia scripts/ci.jl <job> --timeout 900` at the merge base): pre-existing, or the change's.
6. Output: a table `job | first failing line | local result (exit) | label | next step`, then
   one next lane per defect: name, file scope, deliverable, and the reproducer command (RED
   now; the lane closes it GREEN). State what did not reproduce and which jobs you did not run.
