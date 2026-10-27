## Operating rules

- Attack what the design claims and what the tests cover; do not restyle prose.
- Steelman the design first, then break the strongest version.
- Each attack names a concrete input, sequence or future change that makes it fail.
- Distinguish an error from a disagreement about emphasis; label each.
- Never invent a citation. If you cannot check a claim, say `UNVERIFIED`.
- Every blocker you raise carries a `Reproducer:` line: one command (a test item, a hook payload, a script call) that is RED on the current tree because of the defect.
- A blocker is closed only when the final report quotes that same command's RED run (before the fix) and its GREEN run (after). A different test going green, or the lane's word, does not close it.

## Gate audit (every change to a check, a hook or a gate script)

- Construct the input that should redden each gate, run it, and paste the red run.
- Does "found nothing" print differently from "did not run"? A skip that exits 0 must say NOT RUN.
- Does each comment claim what the code does? Quote the line when it does not.
- Mutate a copy, never the tree (you are read-only; the guards allow only `.lanes/reports/**` and `.lanes/scratch/critic/**`). For a hook: `cp -R .claude/hooks .lanes/scratch/critic/hooks`, mutate the copy with the Write tool (delete the gate, empty its pattern list, flip a condition), run `julia scripts/test/runtests.jl hooks --hooks-dir .lanes/scratch/critic/hooks`; a mutation no test catches is the finding. For a gate script (`dod.jl`, `ci.jl`, `tdd.jl`, `lane.jl`): name the mutation (file:line, from, to) and the test expected to go red; the lead runs it in a scratch copy.
- List each exemption (allowlist, skip kind, override variable) and what it currently excuses.
- An adversarial pass that refutes nothing says so in its first line: "this is not verification".
