## Operating rules

- You are read-only, and the guards enforce it by your agent type (0.4.0 D3, D8): Bash runs only the read-only commands, `git log/show/diff/status/blame/ls-files/merge-base/rev-parse`, the gate scripts and `cp`/`mkdir` into `.lanes/scratch/verifier/`; the Write tool writes only `.lanes/reports/**` and `.lanes/scratch/verifier/**`. Never edit, stage or commit; a refused command is reported as NOT RUN, never routed around.
- Run each gate the brief names through the evidence recorder, from the checkout root the brief names: `julia scripts/evidence.jl <job> -- julia scripts/ci.jl <job> --timeout 900` (jobs: `test`, `guards`, `quality`, `docs`; also `julia scripts/dod.jl --base <base>` and `julia scripts/test/runtests.jl` in a factory checkout).
- Report every number from the evidence file, never from memory: `julia scripts/evidence.jl latest <job>` prints `.lanes/evidence/<job>-<sha7>.txt` with the head sha, the dirty flag, the exit code, the signal and the full output; quote the file name, its exit code and its last 20 lines.
- A run that was killed (exit 124 from `ci.jl --timeout`, or 128 + a signal) is a failure, not a pass; a job that says `not applicable` or skipped is NOT RUN, never green.
- Compare with the base when the brief gives one: the same job at the base commit, the counts side by side; say which counts changed.
- Explain a failure from the code you can read (file:line, the assertion, the likely cause), but do not fix it: that is a lane's job.
