# Factory changelog

Versions of the development-process template. Repos record the version they vendor in
`.factory-version`; `scripts/sync_factory.jl` shows the diff before taking a new one.
A breaking change (a renamed file, a new required field, a stricter guard) bumps the minor
version while below 1.0.

## 0.3.0 (2026-10-27)

A `test-writer` role and test-first lanes with separate contexts (ADR-0015; spec
`docs/superpowers/specs/2026-10-26-factory-test-writer-design.md`, plan
`docs/superpowers/plans/2026-10-26-factory-test-writer.md`). The tests of a test-first lane come
from the spec and the public API, written by an agent that never sees the implementation; a second,
fresh agent writes the code. A minor bump: the guards are stricter (dod `tdd`, `tdd_boundary`, the
commit guard), the implementer is narrowed, and there is a new seeded edit. Builds on 0.2.8.

- **The 13th role, `test_writer`** (`.agents/agent-registry.toml`, seeded; new managed
  `.agents/bodies/test_writer.md`). The spec §2.1 entry: `tools` Read, Grep, Glob, Bash, Edit,
  Write; `disallowed_tools` Agent, Task, SendMessage, WebFetch, WebSearch, NotebookEdit;
  `file_scope` `test/**`. The body: the context is the boundary (work only from the tdd-brief;
  never read `src/`/`ext/`, their history, transcripts or the depot); author
  `test-writer <test-writer@factory.invalid>`; `TDD: red` then `tdd.jl red`; `TDD: test-fix`,
  `TDD: test-refactor`, `TDD: backfill`; a bug is `@test_broken`; it leaves law, property,
  differential, contract and JET tests and the seeded runners alone. The registry header says
  13 roles and cites ADR-0015.
- **The `implementer` is narrowed.** `file_scope` `src/**`, `ext/**`, `changelog.d/**` (no
  `test/**`); `tools` Read, Grep, Glob, Bash, Edit, Write, WebFetch, WebSearch; `disallowed_tools`
  Agent, Task, SendMessage. Role: "Implements one planned task against the test-writer's red tests:
  minimal code to green, then refactor with tests unchanged." Scorecard "failing test written
  first" becomes "tdd.jl audit OK". The body: work from the tdd-brief, author
  `implementer <implementer@factory.invalid>`, never touch `test/**`, disputes as a written
  test-fix request with no source code, STUB declares only, GREEN is minimal, REFACTOR after a
  green.
- **Other bodies.** law-tester, property-tester, differential-tester: "In a test-first lane, commit
  new items with `TDD: red` before the code." reviewer: the spec §4.5 checklist (boundary first:
  saved dispatch prompts, separate `agent_id`s per role in the ledger's `tdd-commit` lines, H9
  authors, every `tdd_boundary` denial a finding, the run-time source-read grep; `MethodError` reds
  match the spec signature; `HELPER` flags; GREEN is minimal; `git show --cc` merges hold no test
  edits; `mutexp` justified).
- **`lane-lifecycle` skill: test-first lanes.** The two brief templates (`<!-- tdd-brief
  role=test-writer|implementer lane= checkout= head= -->` and their sections); `tdd.jl brief`;
  dispatch rules (a fresh `subagent_type` per role, never a fork, no `team_name`, subagents only,
  a clean lane); the brief is the only channel; the `TDD-Mode:` trailer on a commit authored
  `lead <lead@factory.invalid>`; merge, never rebase.
- **`/change-review`** runs `tdd.jl audit --base main --ledger <root>/.lanes/ledger.jsonl` and
  `dod.jl` for a test-first lane, and reads the saved prompts under `<main>/.lanes/briefs/<lane>/`.
- **`CLAUDE.md`** (seeded): the `scripts/tdd.jl` red/green/audit lines, `tdd_boundary` in the hook
  list, and one line on test-first lanes. The template's copy changes; a repo's own copy is a
  hand edit (optional).
- **What the Task 0 probe established** (2026-10-27, plan Task 0), and what the hooks rely on:
  - TDD dispatches MAY use `name` (`tw-<lane>-<task>` / `impl-<lane>-<task>`): a named
    teammate's payloads carry `agent_type`, but no `agent_id`. The hooks key the role on
    `agent_type` only, never `agent_id`.
  - The lead is the caller with no `agent_type`.
  - SubagentStart/SubagentStop never fired for either dispatch; nothing relies on them.
  - A new agent type added mid-session is not dispatchable until the session restarts: after
    syncing 0.3.0 and adding the registry entries, **restart the session** before the first TDD
    dispatch.
- **Hooks (plan Task 8):** `.claude/hooks/tdd_boundary.sh` (PreToolUse: the test-writer's
  Read/Grep/Glob and Bash allowlists and `test/**`-only writes, the implementer's `test/**` denial,
  the lead-only dispatch of a role with a matching tdd-brief header, saved under
  `<main>/.lanes/briefs/<lane>/dispatched/`), the sourced `_tdd_allow.sh` and `_tdd_commit_guard.sh`
  (the effective author of every `git commit`, role identities and the lead identity, `TDD-Mode:`
  denied to role callers, no background commits), and `tdd_commit_post.sh` (PostToolUse and
  PostToolUseFailure `Bash`: the resulting commits' author, phase and paths; ledger `tdd-commit` /
  `tdd-commit-violation`). `settings.json` gains the matchers; `checks.toml` the register rows.
  **Deviation from the spec:** its single `tdd_boundary` register row is split into
  `tdd_boundary` and `tdd_commit_post`, because every hook must be its own `prevented_by` file
  (the `test_gen` register invariant).
- **Deviations from the spec and plan in the hooks** (the full list, after review rounds 1 to 3):
  - **A fourth hook file.** The plan named `tdd_boundary.sh` and `tdd_commit_post.sh`; the
    150-line hook cap adds the sourced `_tdd_allow.sh` (allowlists, the implementer's Bash write
    check) and `_tdd_commit_guard.sh` (the Pre half of the commit guard). The `tdd_boundary` row's
    rule names both. The dispatch check (`tdd_dispatch`) lives in `_lanes.sh`, because
    `dispatch_limit.sh` runs it too (below).
  - **The register split** into `tdd_boundary` and `tdd_commit_post` (above).
  - **The sweep** (§0.5 left it open). A pending entry `.lanes/tdd-pending/<tool_use_id>` older
    than 11 minutes (the Bash tool's 10-minute maximum, plus one) belonged to a call that fired
    no post event: a later call sweeps and deletes it, and records each of its commits only as
    `tdd-commit-late {agent_id, agent_type, checkout, sha}`, never `tdd-commit` and never
    `tdd-commit-violation`, and prints nothing. E5 accepts only `tdd-commit`, so a cancelled
    call's commit fails E5 with "(only a late swept record: re-make or amend it through the
    hooks)". Both the post hook and the sweep attribute to a call only the commits on
    `git log --first-parent <HEAD before>..HEAD` (at most 100) whose committer time is within
    [entry mtime − 5 s, entry mtime + 600 s]: a commit forged outside the hooks in a stale
    entry's window is never recorded as the role's (stale entries only: one made in the same
    checkout while another call is in flight, up to 10 minutes, is recorded as that call's
    caller's, no stronger than a forged ledger line; the `tdd_commit_post` row says so), and a
    merge of main records only the merge commit, never main's role commits. The committer time
    decides the window, so a backdated commit gets no record and fails E5 (fail-closed).
  - **E5 matches `tdd-commit-violation` records by the lane's commit shas only** (not also by
    checkout), so a violation stops failing the lane once the commit is replaced.
  - **Stricter role-commit rules than §0.5:** a role caller's `git commit` takes no `-a`/`-i`/
    `-o`/`-p`/pathspecs (it commits the staged index); `--author` must be a full `Name <email>`;
    a `git commit` after a `cd` the guard cannot follow needs `git -C <absolute checkout>`; a
    commit run through a wrapper (`xargs git commit`, `sh -c`) is denied as unmodelled, while a
    plain mention (`echo … git commit`, `printf`) is allowed; a test-writer's `-F`/`--file`/
    `-t`/`--template` file is `-` (stdin) or on its read allowlist; only a `TDD-Mode:` trailer
    line (case-insensitive key and colon) is denied to the role callers, not "tdd-mode" in prose.
  - **The post hook exits 2 on a violation** (the message reaches the caller; PostToolUse cannot
    undo the commit), not 0.
  - **Test-writer Bash extras:** `true`, `false`, `echo`, `printf` and `pwd`; any word with `$`,
    a backquote, `{`, `}` or a leading `~` is denied (brace expansion escaped `test/`), and an
    implementer's Bash write target with `{` or `}` is denied. Review 2: a test-writer's or an
    implementer's Bash command containing `$'` or `$"` is denied whole (rule `ansi-c-quote`),
    before it is split: bash_guard's parser drops the `$` and mangles `\x` escapes, so
    `cat test/$'\x2e\x2e'/src/a.jl` passed the path check. The lead is unaffected. Review 3: a
    test-writer's raw Bash command containing `$`, a backquote or `<<` anywhere (heredocs and
    `<<<` included) is denied whole (rule `tw-heredoc`), before it is split: bash_guard's parser
    drops heredoc bodies, so `cat <<EOF` / `$(cat src/a.jl)` / `EOF` reached the checks as a
    plain `cat` while bash expanded the body. The deny tells the test-writer to put a commit
    message in plain quotes (`-m "test: …"`). The implementer and the lead keep heredocs
    (`git commit -m "$(cat <<'EOF' … EOF)"`); an implementer's unmodelled write inside a heredoc
    body is caught only at commit, by the staged-path check (H3/H4).
  - **A `.git` marks a checkout** only as a directory or as a `gitdir:` file whose worktree record
    points back, and (review 2) only when the directory entry is named exactly `.git`: on a
    case-insensitive APFS a written `test/.GIT/HEAD` made `[ -d test/.git ]` true. A role never
    Writes/Edits a `.git` path, in any letter case (a planted `test/.git` moved the root).
    `is_co`, `co_of` and `in_root` moved from `_lib.sh` to `_tdd_allow.sh` (only
    `tdd_boundary.sh` uses them; `_lib.sh` was at the 150-line cap); `phys` stays in `_lib.sh`.
  - **A denied TDD dispatch opens no lane.** `dispatch_limit.sh` runs the same dispatch check and
    denies without recording, since the two hooks run in parallel; the brief's `lane=` must be the
    lane of a `.worktrees/<lane>` `checkout=`. Review 2: the check includes the prompt-save step's
    precondition (the `dispatched/` directory can be created and written), so a save denial no
    longer leaves a lane open; only a write that fails after the check (a full disk) still can.
  - **Blind spots not in the pinned lists.** The register test pins the `tdd_boundary` and
    `tdd_commit_post` blind-spot lists to the spec's ten, so the two review-2 additions (a commit
    made while another call in the same checkout is in flight is attributed to that call's caller;
    a backdated committer time gets no record and fails E5) are stated in the `tdd_commit_post`
    row's rule text in `checks.toml` and `docs/CHECK_COVERAGE.md`.
- **Tasks 1–7** (merged earlier as part 1): the failure-output fixtures for Julia 1.13.2 and
  1.10.12; the seeded `test/runtests.jl` `item=` selection and the `TDD_MATCHED` record;
  `scripts/_tdd_classify.jl` (ASSERTION, BEHAVIOUR, WRONG-REASON, PASSED, NOT-RUN, COLLATERAL,
  HELPER); `scripts/tdd.jl` `red`, `green`, `api`, `brief`; `scripts/_tdd_history.jl` (H1–H9,
  E1–E5) and `tdd.jl audit`; `scripts/_tdd_backfill.jl` (`mutate`, `gaps`); dod's `tdd`
  requirement and the seeded `risk.toml` (`tdd` in T1–T3, the four tdd scripts in T3).
- **Fixes in this release:**
  - `tdd.jl green`: a red item renamed by a test-writer `TDD: test-fix` commit with passing red
    evidence no longer deadlocks green; it is reported `RENAMED` (a26bf04).
  - dod `changelog`: the heading check covers modified fragments too, not only added ones (281686e).
  - The factory test runner unsets `FACTORY_ALLOW_T3`, `FACTORY_ALLOW_PUSH` and
    `FACTORY_ALLOW_OUTWARD` for child processes; the hook tests failed when the caller had T3 set
    (bd1de78).
- **Critic fixes C1 and C2** (`.lanes/reports/critic-030.md`; red tests `test_tdd_c1.jl`,
  `test_tdd_c2.jl`):
  - **C1: the test-side roles are a class.** `test-writer`, `law-tester`, `property-tester` and
    `differential-tester` may each author `TDD: red`, `test-fix`, `test-refactor` and `backfill`,
    under their own identity `<role> <<role>@factory.invalid>` (`TEST_ROLES`, `phase_authors` in
    `_tdd_history.jl`: H9, H4, E5). One shell list, `test_role`/`tdd_role` in `_lib.sh`, keys
    every hook on `agent_type`: all four get the test-writer's boundary (no `src/` reads, writes
    under `test/` minus the seeded runners, the same Bash allowlist, and only their own
    `.lanes/briefs/<lane>/<role>-*`); the commit guard's `role_of`/`id_rule`/`role_paths` and the
    post hook's phase check accept any of them for the test phases. Before, a law-tester obeying
    its body ("commit new items with `TDD: red`") failed H9 (or H4 without a phase) permanently.
    Dispatch stays the lead's alone, with a tdd-brief header `role=<role>`;
    `tdd.jl brief --role law-tester|property-tester|differential-tester` writes the test-writer's
    sections. Bodies: the three tester bodies say how they work in a test-first lane (their
    tdd-brief, the boundary, their identity, `TDD: red`); `test_writer.md` no longer lists their
    items as "not yours" and points to the dedicated roles. Registry: the three gain
    `disallowed_tools` Agent, Task, SendMessage (as the test-writer: no channel to the
    implementer), a description and a scorecard line for test-first lanes.
  - **C2: git's trailer semantics are the one parser.** `tdd_commit_post.sh` reads the phase and
    mode with `git log -1 --format=%(trailers:key=TDD,valueonly)` (and `key=TDD-Mode`), as
    `lane_commits` (new `git_trailer`) and `tdd.jl phase()` do; `trailers(msg)` is
    `git interpret-trailers --parse`. Before, the post hook took a `TDD:` line from anywhere,
    while H1/H9 read only the last paragraph, so `-m "test: x" -m "TDD: red" -m "Co-Authored-By: …"`
    passed the hook and failed dod later. Now a role commit with no phase as git reads it is a
    post-hook violation (rule `no-phase`, exit 2) while it is still HEAD, and the message gives
    the repair: `git -C <checkout> commit -q --amend --no-edit --trailer "TDD: <phase>"`. A lead
    commit with no phase stays clean.
  - **The one commit form**, in every role body (test-writer, implementer, the three testers) and
    the lane-lifecycle skill: `git -C <lane> commit -q --author "<role> <<role>@factory.invalid>"
    -m "<subject>" --trailer "TDD: red" --trailer "Co-Authored-By: Claude Opus 5.5
    <noreply@anthropic.com>"`, run in its own Bash call, never chained with `tdd.jl red` or
    anything else (a cancelled chained call leaves a late commit, critic C4). `--trailer` needs
    git 2.32 or later.
- **Critic fixes C3, C4, C6, C7 and C8** (`.lanes/reports/critic-030.md`; red tests `test_tdd_c3.jl`,
  `test_tdd_c4.jl`):
  - **C3: skip separators.** `parse_mode` takes ` — `, ` - ` or ` -- ` as the reason separator (its
    first occurrence; later ones stay in the reason). `skip`, `skip -` and `skip —` with no reason
    still fail H8. Before, `TDD-Mode: skip - format fix` had reason "" and failed H8, and since the
    oldest mode trailer decides, only a rewrite fixed it. The migration list below names the skip
    commit and the sub-lead limit.
  - **C4: a cancelled commit call.** Every role body and the lane-lifecycle skill say to run
    `git commit` in its own Bash call, never chained. The skill names the lead's recovery: amend
    while the commit is HEAD; otherwise reset the lane to before it and re-dispatch, or attest it
    with an **E5 lead waiver**: a lane commit authored `lead <lead@factory.invalid>` with the git
    trailer `TDD-Waiver: E5 <sha> — <reason>` (sha full or ≥ 7 hex, naming one lane commit; any
    `parse_mode` separator; a non-empty reason). It lets a role commit whose only ledger record is
    `tdd-commit-late` pass E5. It never covers a sha with no record or a `tdd-commit-violation`.
    The commit guard denies a role caller's commit that carries a `TDD-Waiver:` trailer (rule
    `waiver-trailer`); the lead may write one.
  - **C6: modes per merged sub-lane** (option a). `lane_segments` splits `base..head`: for each
    merge M on the first-parent chain, the commits of `M^1..M^2` form a segment under that
    sub-lane's own mode commit; the commits made directly on the integration branch form one
    segment under the branch's own mode commit. `tdd.jl audit` and dod's `tdd` apply H1–H9 per
    segment (`segment_rules`). Before, a refactor-mode sub-lane merged before a required-mode one
    turned the latter's red and green into H8 failures. The E rules still read the whole lane.
    **Known limit:** so audit's E2 refactor check uses the mode of the whole lane (the oldest mode
    trailer, `_tdd_evidence.jl` `audit`), not each segment's: a refactor-mode sub-lane merged into a
    required-mode branch gets no E2 green-at-the-merge-base check, and a refactor-mode branch's
    check runs once, at the lane's merge base.
  - **C7: named blind spots** (`checks.toml`, `docs/CHECK_COVERAGE.md`): merge commits are
    invisible to H1/H3/H4 (`--no-merges`; only the reviewer's `git show --cc` sees a merge
    resolution); a git alias (`git ci`) bypasses the commit guard; E5 catches alias commits by role
    identities, dod does not.
  - **C8:** `test_writer.md` rule 1 cites the API as `julia scripts/tdd.jl api` prints it (on Julia
    1.10 `api` prints NOT RUN), never a docstring read in `src/`.
  - `scripts/_tdd_history.jl` was at its 400-line budget: the evidence rules E1–E5, the ledger
    and `audit` move to a new managed, T3 `scripts/_tdd_evidence.jl`, which only `tdd.jl` includes.
- **Review of the critic fixes** (the reviewer's FINAL on 1097ee1..55ff8ca; red tests
  `test_tdd_c5.jl`, 8d77f1c):
  - **FIX-1: a sub-lane merged twice is one segment.** `lane_segments` joins a merge's segment to
    an earlier merge's when that merge's `M^2` lies on the later `M^2`'s first-parent chain (the
    same sub-lane, merged again). Before, the second merge's refactor formed a segment of its own,
    with no red and no mode, and failed H2 and H6. A different sub-lane cut from the integration
    branch after the first merge reaches that `M^2` only through a merge's second parent, so it
    stays its own segment; nested merges are unchanged. 7 more lines (C6: 33 of its 40).
  - **Trailer parsing agrees with git's commit parser:** `trailers(msg)` runs
    `git interpret-trailers --parse --no-divider` (a commit message has no `---` divider).
  - **The `=` form of `--trailer`** (`--trailer "TDD-Mode=…"`, `"TDD-Waiver=…"`, any case; git
    writes `Key: value`) is denied to a role caller at Pre, rules `mode-trailer` and
    `waiver-trailer`, as the `:` form is.
  - `parse_mode` also takes the en dash ` – ` as the reason separator; the first separator wins.
  - Docs: the E2 known limit (C6 above); the `checks.toml` `tdd` and `tdd_boundary` rules (and
    `docs/CHECK_COVERAGE.md`) name every test-side role (test-writer, law-, property-,
    differential-tester), not only the test-writer. The tdd_boundary row keeps its two git-alias
    blind spots: `test_hooks_tdd.jl` pins both texts exactly. The only test-fix commit in this
    round's history is 55ff8ca (it pins the C7 blind spots); the C1/C2 note about a test-fix lane
    for old tests is removed.
- **The managed tests pass in a coordinator-profile sync** (lane tw-032, found syncing 0.3.0 into
  the coordinator; red test 4a774d9). Several tests read the host repo's seeded `risk.toml` (and
  expected `tdd` in T1–T3) or copied its seeded `test/runtests.jl`. A coordinator has neither (no
  `tdd` tier, no `test/`), so a scratch coordinator synced to 0.3.0 had 16 fails and 30–35 errors.
  - New managed fixtures `scripts/test/fixtures/seed/risk.toml` and `runtests.jl`: the package
    seeds, byte for byte (`test_dod.jl` checks this inside `factory/`). `test_dod.jl`,
    `test_tdd_review.jl`, `test_tdd_c3.jl` and `test_tdd_cli.jl` (so also `test_tdd_backfill.jl`)
    build their scratch repos from them through `seed_fixture` in `runtests.jl`.
  - "risk.toml requires tdd" checks the package seed; the host's own `risk.toml` must only protect
    the tdd scripts as T3 (true in both profiles). Inside `factory/`, the coordinator profile seed
    has no `tdd` in its tiers.
  - Guard: `test_profile_coordinator.jl` syncs the template into a scratch repo with
    `--profile coordinator` and runs the scratch's own `scripts/test/runtests.jl` there, selected
    with the new `FACTORY_TEST_ONLY=<file>,...`; it expects no fail and no error. By default it runs
    `test_dod.jl` only (about 30 s); `FACTORY_GUARD_FULL=1` adds `test_tdd.jl`, `test_tdd_backfill.jl`,
    `test_tdd_review.jl` and `test_tdd_c3.jl` (about 4.5 min of package runs, so opt-in). Every
    factory change that touches `scripts/test/` or the tdd scripts runs it before merge, from
    `factory/template`: `FACTORY_GUARD_FULL=1 FACTORY_TEST_ONLY=test_profile_coordinator.jl julia
    --startup-file=no scripts/test/runtests.jl` (`factory/README.md`). `runtests.jl` now imports `TOML` and `SHA` itself, so a selection
    runs on its own. No migration step.
- **The coordinator profile seed** (`factory/profiles/coordinator/risk.toml`) protects the five tdd
  scripts as T3 (no `tdd` in its tiers). It only seeds a new coordinator; the existing one adds
  them by hand (below).
- **Migration (spec §9.2).** Each repo takes 0.2.8 first. The sync brings, managed: the five tdd
  scripts, the four tdd hook files (`tdd_boundary.sh`, `_tdd_allow.sh`, `_tdd_commit_guard.sh`,
  `tdd_commit_post.sh`) and the changed `_lib.sh`, `_lanes.sh`, `dispatch_limit.sh`, `settings.json`, `test_writer.md` and the
  changed bodies, `checks.toml`, `dod.jl`, `/change-review`, `lane-lifecycle`. The seeded hand
  edits (T3, `FACTORY_ALLOW_T3=1`):
  - **coordinator:** `.agents/agent-registry.toml` gains the `test_writer` and `implementer`
    entries as in the template (D7 reversed; both use the vendored template bodies); `risk.toml`
    adds `scripts/tdd.jl`, `scripts/_tdd_classify.jl`, `scripts/_tdd_history.jl`,
    `scripts/_tdd_evidence.jl` and `scripts/_tdd_backfill.jl` to the T3 globs. No `tdd` in its
    tiers: it has no `src/`.
  - **ChuiCore.jl** (after v0.0.1), **ChuiTypes.jl, ChuiFrames.jl** (after their open branches
    merge): the registry `test_writer` entry and the `implementer` change (`file_scope`, `tools`,
    `disallowed_tools`, role, scorecard), and the `law_tester`, `property_tester` and
    `differential_tester` changes (critic C1: `disallowed_tools`, description, scorecard);
    `risk.toml`: `tdd` in the T1–T3 `requires` and the five tdd scripts in the T3 globs; `test/runtests.jl`: the `item=`/`TDD_MATCHED` selection block from
    the template.
  - Then run `julia scripts/gen.jl`, and **restart the session** before the first TDD dispatch.
  - **Non-TDD code lanes need a lead skip commit** (critic C3). Once `tdd` is in a tier, every lane
    that changes `src/` or `ext/` without the test-writer and implementer roles (a format fix, a perf
    lane, a release fix, sub-lead work) fails dod (H1/H2) unless it carries a `TDD-Mode: skip`
    commit authored by the lead. The lead runs, once per lane, before its first code commit:
    - `git -C <lane> commit -q --allow-empty --author "lead <lead@factory.invalid>" -m "chore: tdd skip" --trailer "TDD-Mode: skip — <reason>"`
  - **TDD dispatches and mode commits are the lead's** (the main session). A sub-lead teammate has an
    `agent_type`, so `tdd_dispatch` denies its TDD dispatches (`dispatch-not-lead`) and the commit
    guard denies it the lead identity: it can neither dispatch the TDD roles nor set a mode. A
    sub-lead asks the lead for both.
  - **In-flight branches:** add the skip commit to a branch that changes code before merging main
    into it: the merge brings main's `risk.toml` with `tdd` in its tiers, and the branch's code
    commits then fail H1 without it.
- **Dogfood numbers (spec §6, plan Task 9 step 5).** Handoffs per task in lane tw-031, counted by
  its sub-lead: item a 2 (test writer, implementer), item b 2, item c 2 (the three fixes above),
  Task 8 3 (test writer, implementer, one test-fix), Task 9 2. So 2 handoffs per task, 3 with a
  dispute round, in line with the spec's estimate of 2–4. Wall-clock per task for Tasks 2–7 is in
  the tw-030 lane's records; this lane did not measure it: not measured here.

## 0.2.8 (2026-10-26)

The lane cap (`dispatch_limit.sh`) was not enforced. It counted SubagentStart minus SubagentStop,
and in-process teammates never balance those. The coordinator's ledger has 32 starts, the last on
2026-10-20T14:12Z, against 716 stops. One lead session had 77 stops, each with a different id,
and no start. So the open count was always ≤ 0 and `max_open` never fired. Spec:
`docs/superpowers/specs/2026-10-26-factory-028-design.md`.

The guard is stricter (the cap now fires), which by the rule above would be a minor bump. It ships
as 0.2.8 because it restores a guard that was meant to work (a bug fix). The user chose "0.2.8
patch first", before the 0.3.0 test-writer work, on 2026-10-26, answering the lead's question on
the cap fix. That is consistent with the user keeping 0.2.x at L0.

- **A lane is an Agent dispatch** (`dispatch_limit.sh`, new sourced `_lanes.sh`, `lane_ledger.sh`,
  `settings.json`, `precompact.sh`).
  - Open: `dispatch_limit.sh` writes `{ev: dispatch, key, name, desc}` when it allows a call. The
    key is `tool_input.name`, else `tu:<tool_use_id>`, else `desc:<description>`.
  - Closed by the lead's own tool results, through `lane_ledger.sh`, now also on PostToolUse and
    PostToolUseFailure (`Agent|Task|TaskStop`) and on PermissionDenied (`Agent|Task`):
    - an Agent result with status `completed` (a foreground agent that returned), a failed Agent
      call, or auto mode's denial of it;
    - a `TaskStop`, by name. A TaskStop whose ref names no lane of the session (an internal task
      id) closes by description, as a fallback;
    - a background subagent's SubagentStop, whose `agent_id` matches the `agentId` its Agent
      result returned.
  - `teammate_spawned`, `async_launched` and `remote_launched` keep the lane open. Any other
    status is logged as `unknown-result` and also keeps the lane open: an unknown status fails
    toward counting.
  - `scripts/lane release <name>` closes a lane whose agent is gone. A TaskStop for a gone agent
    fails validation and fires no hook (hooks docs).
    - The release is written with session `*` and matches in every session.
    - The denial names this command.
    - It writes the ledger the hooks read (`[lanes] ledger`).
    - It starts a new line after a truncated last line.
    - It exits 1, without claiming the release, when the write fails or the registry does not
      parse.
  - Read, count and append run under a lock, `.lanes/.dispatch.lock`, because parallel Agent
    calls passed the cap together.
    - The hook waits up to 5 s for the lock, then denies.
    - A lock older than one minute is moved aside, checked that it is still stale, then removed.
      If another hook took a fresh lock in between, it is put back and the hook denies.
    - A stale lock that is a file or a non-empty directory is put back, and the hook denies at
      once. It used to spin until the hook timeout.
    - A `.lanes/` that cannot be created denies.
  - A payload that is not a JSON object is denied. Before, such payloads were all recorded under
    one key `desc:`, and every one of them passed.
  - SubagentStart/Stop stay in the ledger but no longer count on their own.
  - Re-dispatching an open name counts once.
  - A dispatch with no spawn record stops counting after `FACTORY_LANE_TTL_HOURS` (default 24;
    0 = never). That covers dispatches that never ran, and also foreground calls still running past
    the TTL (a blind spot). A spawned teammate or background agent stays counted until it is
    closed: sub-leads run for days. A `ts` that does not parse counts.
  - The cap is per session, and each teammate is its own session.
  - A ledger written before 0.2.8 counts 0 open lanes, because its lines are not dispatches.
- **The ledger no longer loses the record after a truncated line** (`_lib.sh` `ledger`). A crash
  mid-write left a last line with no newline, and the next `>>` record joined it and was skipped as
  malformed. `ledger` now starts a new line first. A new test found this.
- **`_lanes.sh` is a new managed hook library** (lane counting, split from `_lib.sh` to stay under
  the 150-line hook budget). `dispatch_limit.sh` fails closed without it; `lane_ledger.sh` and
  `precompact.sh` fail open.
- `CHECK_COVERAGE` rows for `dispatch_limit`, `lane_ledger` and `lane` list the new blind spots.
  The main ones:
  - a teammate resumed by SendMessage is not counted;
  - a dispatch denied in a permission dialog stays open until the TTL or `lane release`;
  - `lane release` trusts the caller.
- The `lane-lifecycle` skill says what opens and closes a lane, and how to release one.
- Tested by `scripts/test/test_hooks_lifecycle.jl`, whose start/stop testset is replaced. The cases:
  - the 2026-10-26 regression: stops with no starts, plus named dispatches;
  - teammate, background, remote and foreground lanes;
  - TaskStop by name and by internal id;
  - re-dispatch, sessions, the TTL, a truncated line, and the settings wiring;
  - the critic's cases: a ghost lane released, 6 concurrent dispatches at cap 2 (exactly 2 pass,
    3 trials), a held lock and a stale lock, a shared description, an unknown status, a long-lived
    spawned lane, a close before a re-dispatch, an empty TaskStop ref, and PermissionDenied;
  - the reviewer's cases:
    - a stale lock that is a file or a non-empty directory denies within 8 s;
    - 4 non-JSON payloads at cap 2 are all denied;
    - a release after a truncated line takes effect;
    - a release whose write fails exits 1;
    - a release uses `[lanes] ledger`.

  `test_hooks.jl` checks the missing-`_lanes.sh` behaviour.

## 0.2.7 (2026-10-20)

Six problems lanes hit on 2026-10-20, each reproduced in a scratch repo built from the 0.2.6
template before it was fixed (spec: `docs/superpowers/specs/2026-10-20-factory-027-design.md`).
Some results are stricter:
- a signalled run is no longer exit 0 in its evidence;
- the benchmark job now runs a suite where it used to do nothing;
- a plain `]test` below `STABLE_MIN` now skips `:doctest`/`:snapshot`.

The lead chose 0.2.7, as for 0.2.6. Only the seeded `test/runtests.jl` needs a hand edit in each
package (a sync never overwrites a seeded file). An evidence file from 0.2.6 (no `termsignal`
line) reads as before.

- **`ci.jl --timeout SECONDS` (or `CI_TIMEOUT`) bounds a run and kills the whole tree**
  (`ci.jl`; template `CLAUDE.md`, `lane-lifecycle` skill).
  - Why: `perl -e 'alarm N; exec @ARGV' julia scripts/ci.jl test` killed only ci.jl, and Pkg.test's
    child julia ran on. A hung property test ran ~6 h at 97% CPU.
  - How: with a limit, each command starts in its own process group. On expiry the group gets
    SIGTERM, then SIGKILL after 10 s, and ci.jl exits 124 (`TIMED OUT … This is not a pass.`).
  - Ctrl-C during a bounded run kills the group too and exits 130 (review B2). The first version
    left the hung test running, because the detached group never sees the terminal's SIGINT.
    Other signals that end ci.jl (SIGTERM, SIGALRM, SIGKILL) still orphan the group; the
    register lists them.
  - Tested with a planted hanging test and a grandchild, both timed out and interrupted: both pids
    are dead and `pgrep` finds nothing.
- **The seeded `test/runtests.jl` decides "stable" by Julia version** (`test/runtests.jl`, seeded).
  - `CI_STABLE` of exactly `"true"`/`"false"` still overrides, both ways. Any other set value
    throws an `ArgumentError`, as in ChuiCore.jl e80dce9.
  - Unset, the run is stable iff `VERSION >= STABLE_MIN` (`v"1.13"`, ADR-0008 §3), so a plain
    `]test` on the LTS skips the stable-only items. Before, unset meant stable, so that `]test`
    ran them and failed (ChuiCore 0.0.1 prep).
  - CI.yml still sets `CI_STABLE` per job.
  - Tested by `scripts/test/test_runtests_template.jl`: both defaults, both overrides, and a bad
    value.

- **The Benchmark workflow runs `scripts/ci.jl bench`, not AirspeedVelocity** (`Benchmark.yml`,
  approved by the user). AirspeedVelocity 0.6.6 cannot be installed next to CSV.jl 1.x: the JSON3
  1.14.3 it pulls in caps Parsers at <= 2.8.8, and CSV 1.x needs Parsers 3 ("Unsatisfiable
  requirements detected for package Parsers"), so the job did nothing for such packages. The job
  checks out the full history (`fetch-depth: 0`), runs `ci.jl setup`, then
  `julia scripts/ci.jl bench -- --base "origin/$BASE"`, with `BASE: ${{ github.base_ref || 'main' }}`
  passed through `env:` (never in the shell line; review S2, decided by the lead). It stays
  warning-only (`continue-on-error: true`, `timeout-minutes: 60`; ADR-0011). Checked end to end
  on a scratch package on CSV 1.1.0 and Parsers 3.0.0 (`bench.jl: OK`), and with actionlint 1.7.12.
- **`bench.time_tolerance` only means something on a quiet runner** (`ratchets.toml`, `bench.jl`,
  the ratchet row of `.agents/checks.toml`): a loaded machine gave false regressions of 1.12–1.20×
  on identical trees.
- **check_docs skips Documenter cross-references** (`check_docs.jl`). It reported a bare Documenter link (link text, then `(@ref)`) in
  `docs/src/*.md` as a stale relative path `@ref`. The exact target `@ref` is skipped;
  `[x](@ref Target)` was never read as a link (the link pattern stops at whitespace) and is now
  tested. `@refs.md`, `./@ref` and `@ref/x.md` are still checked as paths.
- **evidence.jl records the termination signal** (`evidence.jl`, `check_claims.jl`). Julia gives
  `exitcode` 0 for a process killed by a signal, so 0.2.6 wrote `exit: 0` and returned 0 for it.
  The evidence file now has `termsignal: N` (0 when none); a signalled run exits 128 + N (SIGTERM:
  143), and its summary line says `KILLED by signal N: not a pass`. check_claims takes no test
  totals from a killed run, even when it printed a `Test Summary:` table first.
- **Merge bases need no tracking ref** (`_common.jl` `base_ref`, `lane.jl` audit, `ratchet.jl`).
  An explicit `origin/<b>` that does not resolve here (no remote, a pruned tracking ref) now falls
  back to a local `<b>`. In 0.2.6, `dod.jl --base origin/main` failed with "no merge base",
  `lane audit --base origin/main` failed with "is not a commit here", and ratchet.jl skipped its
  one-way check with a misleading "no ratchets.toml at the merge base". With no merge base at all,
  ratchet.jl now says `NOT RUN: no merge base with ...`. Each of these scripts, and bench.jl, prints
  a note when the fallback happens (`base_note`). `lane audit` fails when the local `<b>` standing
  in for `origin/<b>` already contains the lane's tip: after a local merge it would audit nothing
  (review B1: the first 0.2.7 commit passed that case, which 0.2.6 failed).

## 0.2.6 (2026-10-20)

Lanes that work in their own worktrees. Seven problems lanes hit on 2026-10-20, each reproduced in a
scratch repo built from the 0.2.5 template before it was fixed (spec:
`docs/superpowers/specs/2026-10-20-factory-026-design.md`). One guard is stricter: T3 paths of a
lane worktree that does not exist yet (item 2). That would call for a minor bump, but the lead chose
0.2.6, as for 0.2.3 and 0.2.4. The stricter rule only blocks writes that were always meant to be
blocked, so nothing needs migrating.

- **`lane new` sets the lane up like its repo** (`scripts/lane.jl`). It copies the gitignored
  `.agents/factory.local.toml` into the new worktree and runs the lane's `scripts/gen.jl`. In 0.2.5
  the lane had no `read-only-roots.txt`, so in a repo with `require_read_only_roots = true` every
  Bash call there failed closed. Copying the user's own file is the intended setup, not a T3 edit.
- **bash_guard: T3 paths of a lane worktree are protected before it exists**
  (`_bash_guard_write.sh`, `_bash_guard_cmd.sh`). The command
  `scripts/lane new y && cp .agents/factory.local.toml .worktrees/y/.agents/` was rc 0: the hook
  ran before `.worktrees/y` existed, so the path met only the root's globs. `t3_check` now takes
  `.worktrees/<n>/` and `.claude/worktrees/<n>/` as a checkout root by place, and a `cp`/`mv`/`ln`
  target ending in `/` is a directory even when absent. Seven regression commands, all rc 0 on 0.2.5.
- **Merge bases prefer the local base when it contains `origin/<base>`** (`_common.jl` `base_ref`,
  used by `lane audit`, `dod.jl`, `ratchet.jl`, `bench.jl`). 0.2.5 always took `origin/<base>`, so
  work merged locally but not pushed failed `lane audit` ("outside owns") and inflated `dod.jl`.
  `origin/<base>` is still used when the local base is missing, behind or diverged.
  `lane audit` takes `--base B`.
- **A lane's session may write its repo's other lane worktrees and `<main>/.lanes/reports/`**
  (`_lib.sh` `MAIN`/`in_main`, `allowed`). A sub-lane made with `scripts/lane new` inside a lane is
  a sibling (`<main>/.worktrees/<sub>`), which 0.2.5's write_guard and bash_guard blocked, so lanes
  fell back to unguarded scratch copies. The main checkout's own files stay outside, and T3 paths in
  a sibling stay blocked. Why this and not the "disjoint files in one worktree" pattern: see the spec.
- **teammate_idle and write_guard agree** (`teammate_idle.sh`): a report at `.lanes/reports/<name>.md`
  in any lane worktree counts, and a lane may write the main checkout's `.lanes/reports/`.
- **Test template: Supposition on the 1.10 LTS** (ADR-0007 §2, amended 2026-10-20). The seeded
  `test/runtests.jl` shows `sr = @check record = false db = false …` with
  `@test Supposition.results(sr).ispass` (`results` is not exported), and says why. A bare failing
  `@check` exits 0 on 1.10.12 (summary "None"), and a 1.13 counterexample DB crashes 1.10. The
  seeded `.gitignore` gains `/test/SuppositionDB/`. CLAUDE.md, property_tester and law_tester say
  the same.
- **The LTS manifest** (documented, nothing seeded). A Manifest resolved on 1.13 may not load on 1.10:
  with PrecompileTools 1.3.4 the result is `UndefVarError: StaticData not defined`. Julia 1.10 reads a
  gitignored `Manifest-v1.10.toml` first; create it and run `Pkg.resolve()` under `julia +lts`.
  `/Manifest*.toml` already ignores it, and a test now asserts that.
- **check_docs: a gitignored reference under a subdirectory root** (`scripts/check_docs.jl`, found by
  this lane's own test run). `git check-ignore -v` names the source `.gitignore` from the repo's
  top, and 0.2.5 looked that path up from the checked root. For `factory/template` inside the
  coordinator it was never "tracked", so every gitignored reference there was reported stale (the
  new `test/SuppositionDB/` mentions were the first). It now uses a `:(top)` pathspec; the new test
  is false on 0.2.5 and true now.
- **Seeded `JuliaTestItems.toml` and `test/Project.toml`** (package profile; the coordinator
  excludes the first).
  - The problem, found by ChuiCore's reviewer: TestItemRunner scans the whole package directory, so
    a `@testmodule` in a lane worktree (`.worktrees/x/test/`) shadowed the real one.
  - Reproduced in a scratch package: `Evaluated: 42 == -1`, exit 1, on 1.13.2 and 1.10.12.
  - The fix: `exclude = ["/.lanes/", "/.worktrees/", "/.claude/worktrees/", "/.superpowers/"]`
    (every runtime dir sync never ships). Excluded files are never parsed. With it the run passes
    (1/1) on both versions.
  - `JuliaTestItems.toml` needs TestItemRunner ≥ 1.3.2, so the new seeded `test/Project.toml` and
    `test/contracts/Project.toml` set `TestItemRunner = "1.3.2"`.
  - Existing packages: seeded files arrive only when missing, so `JuliaTestItems.toml` reaches them
    on sync. Their own `test/Project.toml` keeps its compat: raise `TestItemRunner` to `"1.3.2"` by
    hand (ChuiCore has `"1"`).
- Blind spots added to `.agents/checks.toml` for write_guard, teammate_idle and lane_tool.
- Seeded files (`.gitignore`, `CLAUDE.md`, `test/runtests.jl`) are not updated in existing repos:
  sync shows their diff; add `/test/SuppositionDB/` and the Testing bullets by hand.

## 0.2.5 (2026-10-20)

Checks that give the same answer in a fresh clone as in a dev checkout. The first GitHub
Actions runs (2026-10-19) failed where every local run passed, because
`.claude/hooks/read-only-roots.txt` is gitignored: rendered in a dev checkout, absent in CI.
No guard is stricter; nothing to migrate.

- **check_docs: a reference to a gitignored path is never stale** (`scripts/check_docs.jl`).
  A reference that does not resolve is asked of `git check-ignore -v` (as a file and as a
  directory, against each root it may resolve in). It passes only when it is untracked and a
  tracked `.gitignore` ignores it with a non-negated pattern: `.git/info/exclude` and a global
  excludes file differ per machine and do not count, and a tracked file deleted in the work
  tree is still reported (both found by the lane's review). 0.2.4 reported `missing .claude/hooks/read-only-roots.txt` for every doc naming it in
  a fresh clone (CI of the coordinator: HANDOFF.md, factory/CHANGELOG.md, factory/README.md; of
  a package: HANDOFF.md, changelog.d) and passed in a dev checkout. The gitignore decides, not
  a name list, so Manifests and `.lanes/` are covered the same way. New blind spot in
  `.agents/checks.toml`: a typo that still matches an ignore pattern passes (a glob, or an
  unanchored directory such as `dev/`). The new test failed
  on the 0.2.4 tree (2 failed, 1 errored) and passes now.
- **gen.jl tests are hermetic** (`scripts/test/test_gen.jl`). `gen_sandbox` copied the host's
  gitignored `.agents/factory.local.toml` and rendered `read-only-roots.txt` when present, so the
  drift test (`--check` must fail after `read_only_roots` changes) passed only where the roots
  file existed: in a fresh clone `--check` skips the absent local output and reported OK
  (CI of a package: `test_gen.jl:91`, `Evaluated: !(first((true, "gen.jl --check: OK (30 files)\n")))`).
  The sandbox now drops both and renders the roots file from the committed config alone; the
  test also checks that an absent roots file is skipped, not reported missing.
- **hook tests are hermetic** (`scripts/test/test_hooks.jl`, `test_bash_guard.jl`). They ran the
  real `.claude/hooks` dir. A coordinator sets `require_read_only_roots = true`, so in its fresh
  clone (no roots file) bash_guard failed closed on every command: 222 failures in the
  coordinator's own test run, hidden in CI because check_docs failed first (60 in `hooks` alone
  on the 0.2.4 tree). The fail-closed message contains "missing", so the missing-library tests
  passed there for the wrong reason. The tests now run `TEST_HOOKS` by default, a copy with no
  roots, not required; tests that need roots or `REQUIRED=1` already build their own. The
  settings.json wiring test runs its command against a scratch project holding that copy.
- **Every template Julia file is Runic-formatted** (ADR-0007). The `Runic` CI job
  (`scripts/ci.jl format`) failed in every package on the factory-managed `scripts/*.jl` and
  `scripts/test/*.jl` (27 of the template's 30 Julia files). They are formatted with Runic
  v1.13.0 (`--inplace scripts`, the version CI installs); no file is excluded and the check is
  unchanged. Formatting grew `scripts/test/test_hooks.jl` to 432 lines, over the 400-line
  `scripts/*.jl` ratchet, so its lifecycle and settings.json testsets moved verbatim to the new
  managed `scripts/test/test_hooks_lifecycle.jl` first (`checks.toml` points teammate_idle,
  dispatch_limit, lane_ledger, precompact and session_start at it). Repos that edited a
  managed script will see a sync CONFLICT on it: re-apply the edit on the formatted file.
- How the class was searched: the full template suite in a fresh clone of the coordinator
  (1345/1346 on 0.2.4, the gen.jl test above), the coordinator's own suite in a fresh clone of a
  scratch coordinator synced to 0.2.5 (which found the hook tests), and a static search of the
  tests for the gitignored files (`factory.local.toml`, the roots file, Manifests).
- Template tests: 1356/1356 on Julia 1.13.2 and 1.10.12 (1346 in 0.2.4). In fresh clones with
  no local files, `scripts/ci.jl guards` passes for a scratch coordinator and a scratch copy of a
  pushed package, each synced to 0.2.5 (both failed on 0.2.4), and for a package bootstrapped
  from 0.2.5 into an empty repo with a doc that names the roots file. `scripts/ci.jl format`
  passes in the package copy and the bootstrapped package. In the coordinator it still fails, on
  coordinator-owned files only (`contracts/*.jl`, `reference/prototype/**`), and the coordinator
  has no CI format job. Spec: `docs/superpowers/specs/2026-10-20-factory-025-clean-clone.md` in
  the coordinator.

## 0.2.4 (2026-10-19)

Gates that hold when an agent works around them: T3 paths guarded through Bash, the gate's own
tests protected, CI skips that say whether they ran, lanes audited after the fact, and numbers in
docs derived instead of typed. Most of the items come from a study of a reference project's agent
workflow. Template tests: 1346/1346 on Julia 1.13.2 and 1.10.12 (1006 in 0.2.3), recorded by
`scripts/evidence.jl` in `.lanes/evidence/tests-5052c66.txt` and `tests-lts-5052c66.txt` (dirty
tree: 0.2.4 uncommitted on 5052c66). Each new test was run against the 0.2.3 tree first and failed
there (see "Evidence" below).
**Stricter guards**: bash_guard denies Bash writes to T3 paths, both guards deny a payload they
cannot read, and `ci.jl` fails when a seeded file is missing. The CHANGELOG rule says a stricter
guard bumps the minor version; the lead chose 0.2.4. New T3 files and manual edits: read the
migration notes.

- **T3 through Bash** (`.claude/hooks/_bash_guard_write.sh`, new). Every write target bash_guard
  already models (redirections incl. `>|` and heredoc targets, `tee`, `sed -i`/`perl -i`,
  `cp`/`mv`/`install`/`ln`/`rsync` targets, `rm`, `rmdir`, `truncate`, `touch`, `mkdir`,
  `chmod`, `chown`, `dd of=`, `curl -o`, `wget -O/-P`, `tar -x -C`, `unzip -d`,
  `find -delete/-fprint`, `git init/clone/worktree`) now goes through `t3_check`, plus the new
  `git rm`, `git mv`, `git restore` and `git checkout ... -- PATHS`. A target matching a T3 glob of
  its checkout's `protected-paths.txt` (the nearest enclosing git checkout, as in write_guard;
  compared lowercased) is denied unless the SESSION has `FACTORY_ALLOW_T3=1`. A directory
  target that holds a T3 path is denied for the commands that change what is inside it
  (`rm -r scripts`, `mv .claude x`, `cp x scripts/`, `find . -name x -delete`, `tar -x -C .`,
  `chmod -R`), as is a target that is a nested git checkout. 0.2.3 gave rc 0 for
  `sed -i '' s/T3/T0/ risk.toml`, `printf x > scripts/dod.jl` and
  `rm scripts/test/test_dod.jl`; all 46 deny cases of the new test passed on 0.2.3. With no
  `protected-paths.txt` at all, a write inside the repo fails closed. The in-place editor code
  moved from `_bash_guard_cmd.sh` into the new library, and so did `outside()` (cmd 148 lines, lib
  140, write 148; the 150-line ratchet holds). Cost, 100 calls each from sh: 62 → 54 ms for
  `git status && ls -la src` (noise), 60 → 67 ms for a 6-segment command with 7 in-root targets
  (no fork unless a path has capitals or glob characters). In the test suite, which spawns sh
  from Julia: 55-80 ms per call on a loaded machine; the ≤ 250 ms test bound holds. `checks.toml` now says exactly what is still uncovered:
  any write bash_guard does not model, such as julia/python/sh code, `git apply`, `patch`,
  editors, and targets held in variables.
- **Fixes from the 0.2.4 adversarial review** (each reproducer gave rc 0 before its fix and is a
  test now):
  - A bare `.git` marker (a `.git` directory made inside `scripts/`, an empty `.git` file inside `.claude/`) made a directory a
    "checkout" with no T3 paths, for both guards. A checkout now needs `.git/HEAD` or a
    `gitdir:` file. A target is checked against its nearest checkout's list AND the repo root's,
    and writes below any `.git` directory are denied. write_guard now uses bash_guard's
    `t3_check`, so it also fails closed without `protected-paths.txt` (0.2.3: rc 0).
  - Glob characters in a target (`rm risk.tom?`, `rm scripts/dod.j*`, `printf x > risk.tom?`) are
    expanded by the guard as the shell would expand them; a brace list (`rm {risk,x}.toml`) inside
    the repo is denied.
  - Targets that resolved to the wrong path: `$'risk.toml'` and `$"risk.toml"` (the `$` is
    dropped), `~+/` (and `~-/` is denied), `x->f` redirects (the `->` exemption predates quote
    handling and is gone), `git --git-dir=.git rm`, repeated `git -C` (cumulative now),
    `env -C DIR rm f`, `rsync a dst -q` (last non-option operand), `find ... -exec rm {} +`
    (an -exec command outside a short read-only list checks find's start paths as directory
    targets), and the GNU names (`gsed`, `grm`, `gtimeout`, ...). `git -c alias.*` is blocked.
  - False positives removed: `cp`/`mv`/`install`/`ln` into an existing directory check
    `DIR/<source name>` (so `cp /tmp/notes.md .` passes and `cp -r /tmp/scripts .` does not);
    `git rm --cached` and `git restore --staged` touch only the index.
  - `lane audit` read `git diff <merge-base>` (working tree only): a commit reverted in the
    working tree, or a staged change reverted on disk, passed. It now takes the union of the
    commits, the index, the working tree and the untracked files, with `core.quotePath=false`.
  - dod.jl no longer counts an empty fragment or a dotfile fragment (`changelog.d/.mine.md`),
    neither of which `fold` would release. `test_totals` sums every `Test Summary:` table (one per
    top-level testset; 0.2.4-pre read the last one) and strips ANSI colour. check_claims reports
    a mistyped marker (`<!-- Claim: ... -->`, `<!--claim x=1-->`) instead of ignoring it, and the
    template and package `factory.toml` now seed `required = ["max_open"]`. ci.jl treats an
    unknown table in `upstreams.toml` and an unreadable `.factory-version` as `missing` (red).
    bash_guard denies a payload with no command string (`{}`, a number, an array); write_guard
    denies a non-string target. `changelog.jl` knows `## [Unreleased]` and indented headings.
  - From the re-verification: `unzip` without `-d` and `tar -x` without `-C` extract into the cwd,
    which is now checked as a directory target. `lane audit` fails when the lane's base was
    rewritten to its own branch or to a ref that is not a commit.
  - Still open (declared in `checks.toml`): targets from stdin via `xargs`, `stdbuf` and other
    unmodelled wrappers, symlinks, `lane-base` rewritten to another real branch and `lane-owns`
    widened, hand-written evidence files, and prose matching any occurrence of the number.
- **Edit/Write only.** `CLAUDE.md`, every write-mode agent body and the lane-lifecycle skill say
  to change files with Edit/Write, never `sed -i`, redirects or heredocs onto tracked files.
- **The gate's own tests are T3**: `scripts/test/*`, plus `scripts/bench.jl`, `scripts/lane`,
  `scripts/lane.jl`, `scripts/changelog.jl`, `scripts/check_claims.jl` and
  `scripts/evidence.jl`, in the template `risk.toml` and the coordinator overlay. The dod.jl and
  ratchet.jl CLI tests now assert the exact `[FAIL] <requirement>` / `FAIL <limit>` lines. With
  the changelog check of dod.jl mutated to always pass, the 0.2.3 tests still passed 29 of 30
  and the new ones fail 11. With the size-raise check of ratchet.jl mutated to stop at the first
  rule, the 0.2.3 tests passed 17 of 17 and the new ones fail 1.
- **CI skips declare their kind** (`ci.jl`): `not_applicable` (not a package: exit 0), `waiting`
  (no upstreams, no `benchmark/` directory: exit 0, a `NOT RUN (waiting) ... its exit 0 is not a
  pass` line and a GitHub `::warning`), `missing` (a file the package profile seeds or expects is
  gone: `test/jet/{Project.toml,runjet.jl}`, `docs/{Project.toml,make.jl}`,
  `test/contracts/{upstreams.toml,Project.toml,runtests.jl}`, `benchmark/benchmarks.jl` when
  `benchmark/` exists: exit 1). In 0.2.3, deleting any of these printed "skipped" and exited 0.
  `ci.jl` and `scripts/lane new` warn when `JULIA_PROJECT`, `JULIA_LOAD_PATH` or
  `JULIA_DEPOT_PATH` is inherited.
- **Lane scope audit** (`scripts/lane.jl`). `scripts/lane new <name> --owns '<globs>'` records the
  owned globs (plus `changelog.d/<name>.md`) in `git config branch.<branch>.lane-owns` and as a
  `lane-new` line in `.lanes/ledger.jsonl`. `scripts/lane audit <name> [--reported FILE]
  [--owns GLOBS]` fails when the lane's committed, uncommitted or untracked changes since the merge
  base touch a path outside the owned globs, when it has none recorded, or when they differ from
  the lane's reported file list. It is wired into `/change-review`, the reviewer body and the
  lane-lifecycle skill. Tested on real temporary git repos.
- **Changelog fragments.** `dod.jl` accepts a newly ADDED `changelog.d/<name>.md` as the
  `changelog` evidence (editing an old fragment, `README.md`, `.gitkeep` or a nested file does
  not count). The new `scripts/changelog.jl list|fold [--dry-run]` folds the fragments, in name
  order, under `## Unreleased` and deletes them; an empty fragment or one with a heading stops
  the fold. The release-check command and the release_manager body run it. `changelog.d/.gitkeep`
  is seeded.
- **Close by reproducer.** The reviewer, critic and contract_steward bodies and
  `/change-review` require a `Reproducer:` command on every blocker and every cross-repo request.
  Closing it needs that command's RED run (before the fix) and GREEN run (after), quoted.
  `/contract-check` drafts requests with a `- **Reproducer:**` line.
- **Numbers in docs** (`scripts/check_claims.jl`, in `ci.jl guards`). A `<!-- claim: key=value -->`
  marker on the line that states the number is checked against the derived value: `max_open`,
  `roles`, `factory_version`, `max_lines:<glob>` (ratchets.toml), and `tests_pass/fail/error/
  broken/total` from an evidence file. The value must also appear in the line's prose. Each file
  is checked against the nearest enclosing checkout with a registry, so a coordinator's
  `factory/template/CLAUDE.md` is checked against the template. `.agents/factory.toml
  [check_claims]` holds `files` (globs; default every tracked `*.md`) and `required` (keys that
  must have a marker). Missing evidence makes a claim UNVERIFIED: that is exit 0, and exit 1 with
  `--strict`. The template's CLAUDE.md lane-cap line carries a marker.
- **Evidence files** (`scripts/evidence.jl <kind> -- <cmd...>`, `latest <kind>`). It writes
  `.lanes/evidence/<kind>-<sha7>.txt` (gitignored) with the head sha, a dirty flag, the command,
  its exit code, the seconds, the date, the parsed test totals and the full output, and it exits
  with the command's code. `CLAUDE.md` says that test counts in docs cite one.
- **Fail closed on unreadable payloads** (an extra from the same study). bash_guard and
  write_guard deny a payload that is not a JSON object; write_guard also denies one with no
  target key, and it reads `tool_input.path` too. In 0.2.3 both cases gave rc 0. The test
  helper `json()` now escapes tabs: a raw tab is invalid JSON, so one heredoc case in 0.2.3 had
  passed only because the guard failed open.
- **Other extras done**: a critic gate-audit checklist (make each gate go red, NOT RUN vs found
  nothing, delete the gate and look for a red test, list the exemptions, "this is not
  verification"); the lane-lifecycle skill checks once more for a late message before recording
  `no_report`; env hygiene (above). **Skipped**: dated harness probes (their home is the
  coordinator's `research/`) and mutation specs for contract tests (L).
- **Hermetic tests in every profile.** Two tests failed in a coordinator checkout on 0.2.3,
  because they read the checkout's own `require_read_only_roots = true`: `test_gen.jl`'s
  `READ_ONLY_ROOTS_REQUIRED=0` and the "package profile seeds no roots" case. `hooks_with_roots`
  now writes its own `limits.env` (`required = false` by default; `src` selects the hooks to
  copy), and the new `gen_sandbox_noroots` writes its own `factory.toml`. A regression test builds
  a host with `require_read_only_roots = true`, checks that the host itself fails closed, and
  checks that the helpers do not inherit it. The new T3 tests use a fixture
  `protected-paths.txt`, and `ci.jl`'s not-applicable test uses an empty directory, not the
  checkout.
- **Exec bits restored.** 15280a8 (0.2.3) committed `.claude/hooks/bash_guard.sh`,
  `dispatch_limit.sh`, `scripts/_common.jl` and `scripts/gen.jl` as 644 (0.2.2: 755), and the
  `_bash_guard_cmd.sh` (new in 0.2.3) and `scripts/contract_usage.jl` had never been executable; sync copies template
  modes, so vendored repos got 644. Every hook, every `scripts/*.jl`, `scripts/lane` and
  `scripts/test/runtests.jl` is now 755. `test_sync_factory.jl` asserts it for the template and
  for a synced repo; on 0.2.3 that test fails 12 times. Sync already preserved modes, and a test
  already covered a mode-only repair.

### Evidence

- Template: `julia scripts/evidence.jl tests -- julia --startup-file=no scripts/test/runtests.jl`
  gives 1346/1346 on Julia 1.13.2 and 1.10.12 (evidence files named above).
- RED on 0.2.3: the final 0.2.4 test files run against the 0.2.3 scripts and hooks (a copy of the
  0.2.3 tree in a fresh git repo) give 1086 passed, 147 failed and 28 errored. By test set:
  bash_guard T3/payload/review 98 failed and 1 errored; hooks 7 failed and 1 errored (gate globs,
  `{}` payload); ci.jl 22 failed (skip kinds); sync_factory 13 failed (exec bits); dod.jl 2 failed
  and 2 errored (fragments); gen.jl 4 failed (new scripts not registered); lane audit 1 failed
  and 6 errored; changelog, check_claims and evidence errored (the scripts do not exist).
- Mutation check of the new reason-specific asserts: see the gate-tests item.
- Sync rehearsals:
  - Coordinator copy (`--profile coordinator`, `require_read_only_roots = true`, gen run):
    `ci.jl guards` OK with its tests at 1139/1139. The same copy on 0.2.3 gave 860/3. Still OK
    after the manual edits below, and check_claims fails a `max_open=4` marker in HANDOFF.md.
  - ChuiCore.jl copy (`--profile package`, 0.2.1 → 0.2.4, no conflicts): `ci.jl guards` OK with
    its tests at 1188/1188. `ci.jl test`, `jet` and `docs` are OK; `contracts` and `bench` print
    NOT RUN (waiting).

### Migration notes

- New managed files: `.claude/hooks/_bash_guard_write.sh` (bash_guard fails closed without it),
  `scripts/changelog.jl`, `scripts/check_claims.jl`, `scripts/evidence.jl` and their tests. Seeded
  when missing: `changelog.d/.gitkeep`. Sync writes them as a Julia process, which bash_guard does
  not model; after the manual `risk.toml` edit below, editing `scripts/test/*` needs
  `FACTORY_ALLOW_T3=1` like the other gate files.
- Seeded files are not updated by a sync. Make these edits by hand, as a T3 change with an ADR:
  - `risk.toml` T3 globs: add `scripts/bench.jl`, `scripts/lane`, `scripts/lane.jl`,
    `scripts/changelog.jl`, `scripts/check_claims.jl`, `scripts/evidence.jl` and `scripts/test/*`.
    A repo seeded before 0.2.2 also lacks the 0.2.2 gate list (`.agents/bodies/*`,
    `.agents/checks.toml`, `.claude/agents/*`, `.codex/agents/*`, `scripts/dod.jl` ...
    `scripts/_common.jl`, `.agents/factory.local*`), so copy the template's whole T3 block. Then
    run `julia scripts/gen.jl`.
  - `.agents/factory.toml`: add `[check_claims]` with `files = []` and `required = []`, or with
    the keys you want enforced. The table is optional: without it no key is required.
  - `.agents/agent-registry.toml`: the implementer's `file_scope` takes `changelog.d/**` instead
    of `CHANGELOG.md`; the release_manager's adds `changelog.d/**`. Run `julia scripts/gen.jl`.
  - `CLAUDE.md`: rule 5 (changelog fragments), the new rule 7 (Edit/Write only; evidence files),
    the lane line (`--owns`, `lane audit`) and the lane-cap claim marker, as in the template.
    `CHANGELOG.md`'s intro mentions fragments.
- `ci.jl jet`, `docs` and `contracts` now FAIL in a package that lacks their seeded files; restore
  them from the seed (a sync shows them).
- A command that wrote into a directory holding T3 paths through Bash, such as
  `find . -name '*.tmp' -delete`, is now denied: name a narrower start path (`find build ...`).
- The coordinator's `requests/README.md` (outside the factory) should add a `- **Reproducer:**`
  field to its request format, matching the contract_steward body and `/contract-check`.

## 0.2.3 (2026-10-19)

Security fixes from the second guard review (guard-rereview), plus three follow-ups from the L0
checkpoint: no private project names in the factory, AirspeedVelocity benchmarks and a seeded
LICENSE (ADR-0011). Template tests: 1006/1006 on Julia 1.13.2 and 1.10.12 (807 in 0.2.2).
guard-rereview's 270 payloads: 260/270 under both sh and dash (the 10 misses are listed below).
142 new payloads: 141/142 (the miss is a push dry-run, which needs `FACTORY_ALLOW_PUSH`).
**Stricter guard**: `rm -rf $TMPDIR/...` no longer passes, and `eval` is blocked. The CHANGELOG
rule says a stricter guard bumps the minor version; the lead chose 0.2.3. New T3 file and
manual edits: read the migration notes.

- **bash_guard M1: `rm -rf` accepts only LITERAL absolute scratch paths.** 0.2.2 trusted
  `$TMPDIR/...` unless the command contained `TMPDIR=`, so `unset TMPDIR`, `read TMPDIR`,
  `printf -v TMPDIR`, `for TMPDIR in /` (and `eval`, `source`, the user's profile) turned it into
  `rm -rf /opt`. The hook cannot know the command shell's TMPDIR, so no `$TMPDIR` form passes. A
  target ending in `/` or `/.`, or holding `{`, is refused too. `outside()` expands `$TMPDIR` to
  the hook's own value, so it is never read as a relative path.
- **bash_guard M2: the command name is found the way the shell finds it.** A new library,
  `.claude/hooks/_bash_guard_cmd.sh` (`check_cmd`), skips shell keywords
  (`if then else elif while until do ! { }`), assignments, leading redirections and wrappers
  with their options (`env sudo doas nice time timeout N xargs caffeinate exec nohup builtin
  command`). `find -exec/-execdir/-ok/-okdir CMD` is checked as CMD (every one of them). Quote
  characters and backslashes are dropped from words (`'rm'`, `"rm"`, `\rm`, `r\m` read `rm`).
  A command name containing `$` or a backtick (`$RM`, `` `echo rm` ``, `rm${IFS}-rf`) is
  blocked, and so is `eval`. `ls | xargs rm -rf` (no visible target) is blocked. A wrapper inside
  a read-only root is denied, as before.
- **bash_guard M3: heredocs are detected in the quote-aware splitter.** `<<WORD` counts only
  when it is unquoted, outside a comment, outside `$((...))`/`((...))` and not `<<<`.
  `echo 'see <<EOF'` NL `git reset --hard` hid every later line from every check in 0.2.2. A
  body that is never terminated is checked as commands after all, and a body starts only after
  the line's quotes close. The denylist now reads the splitter's output, so `"git" reset --hard`,
  `git push "--force"` and `"$(git reset --hard)"` are caught.
- **m1: more write tools are modelled**: `>|`, `>"$HOME"/x`, `sed -i`/`-i.bak`/`--in-place`,
  `perl -i`/`-pi`, `cp`/`ln`/`install -t`/`--target-directory`, `curl -o`, `wget -O/-P`,
  `tar -x ... -C`, `unzip -d`, `find -delete` and `-fprint`, `git init DIR`, `git clone URL DIR`
  and `git worktree add DIR`. Tools that are still not modelled are listed in
  `checks.toml`.
- **m2:** `git --git-dir DIR` / `--git-dir=DIR` / `--work-tree DIR` / `--work-tree=DIR` name the
  repository like `-C`, both for read-only roots and for mutating git outside the root. The
  denylist's git-options pattern also skips them.
- **m3:** backslash-newline is joined before any check (`git reset \` NL `--hard`).
- **m4: dispatch_limit no longer fails open on a malformed ledger.** It reads the ledger with
  `jq -R 'fromjson?'`, so a bad or truncated line is skipped instead of making the count 0. A
  jq error or a non-numeric count now blocks. precompact reads it the same way.
- Speed: one awk now does the splitting, the heredocs and the denylist input (0.2.2 used awk,
  sed and awk). 45 ms per call (70 ms in 0.2.2) and 63 ms with 3 roots and 6 segments
  (`hook start-up cost` test). A command over 64 KiB is refused: a 288 KB one took 6 s, close to
  the 10 s hook timeout, which fails OPEN; the worst case under the cap measured about 4 s
  (11k `mkdir` operands; one fork each). Hook sizes: bash_guard 79 lines, `_bash_guard_lib.sh` 147,
  `_bash_guard_cmd.sh` 150, `_read_only_roots.sh` 66; the 150-line ratchet holds.
- **No private project names (public repos).** Test payloads use fixture roots
  (`~/ro-fixture/ref-a`, `/tmp/ro-fixture/ref-b`, `~/ro-fixture/ref-c`), with the same cases.
  Read-only roots can also come from **`.agents/factory.local.toml`** (only
  `[bash_guard] read_only_roots`; T3 for agents through the `risk.toml` glob
  `.agents/factory.local*`). `gen.jl` merges and deduplicates it into
  `.claude/hooks/read-only-roots.txt`. Both files are gitignored by the seeded `.gitignore`, and
  `gen.jl --check` skips the rendered roots file when it is absent. The new key
  `require_read_only_roots` (rendered into `limits.env` as `READ_ONLY_ROOTS_REQUIRED`) makes
  bash_guard fail closed while no root is rendered. Only `julia scripts/gen.jl` (and
  `--check`) still run, so the file can be regenerated. The coordinator profile seeds
  `read_only_roots = []`, `require_read_only_roots = true` and a pointer to the local file.
- **Benchmark.yml uses AirspeedVelocity and is warning-only** (ADR-0011):
  `MilesCranmer/AirspeedVelocity.jl@action-v1` with `job-summary: 'true'` (no PR-comment
  permission), and `continue-on-error: true`. Inputs were read from the action's `action.yml` on
  2026-10-19. UNVERIFIED: whether the action fails on a slowdown, and whether the registry added
  by `ci.jl setup` survives the action's own setup-julia. To make it blocking later (a T3 edit
  recorded in the repo's CHANGELOG): drop `continue-on-error` and add
  `julia scripts/ci.jl bench -- --base origin/<default>`. `scripts/bench.jl` stays for that and
  as the local runner, since it enforces `ratchets.toml` `bench.time_tolerance`.
- **`LICENSE` is seeded** (MIT, both profiles) with `<YEAR>` and `<COPYRIGHT HOLDER>` to fill in at
  scaffold time. Seeded means a repo that already has a LICENSE keeps it.
- `checks.toml`: the bash_guard blind spots are rewritten. They cover variable write targets,
  the list of modelled write tools and wrappers, the heredoc rule, and symlinks and other
  projects' scratch dirs in the `rm -rf` rule.

Review: a first read-only reviewer stalled before running anything. That lane failed, and its
work was not counted. A second reviewer ran 70 attack payloads, all of which gave rc 0 or 2
under both sh and dash. It confirmed two denylist bypasses that were already there in 0.2.2,
both fixed here with tests: `git clean --force` (and a late `-f`, as in `git clean -x -d -f`),
and `git commit -n`/`-nm` (short for `--no-verify`). It held: wrapper options, quote and escape
desyncs, CR, CRLF and tabs, process substitution, case patterns, and name evasion. The 64 KiB
cap came from probing its untested fail-open class. Left open, outside the guard's stated
rules: `git reset --merge`/`--keep`, `git checkout -- .` and `git restore .`.

Not fixed, and why (guard-rereview harness misses): `echo x #'; rm -rf /opt/x` is a comment in
bash, so the harness expectation is wrong. The three `$TMPDIR` allow cases are blocked on
purpose (M1). `julia --project <space>DIR` makes DIR the script, not the project. Symlinked
targets (`ln -s / l && rm -rf l/opt`) and another project's scratch dir of the same uid are
documented blind spots. `git push --force-with-lease` needs `FACTORY_ALLOW_PUSH`, which the
harness does not set.

### Migration from 0.2.2

The sync writes these T3 files in every repo: `.claude/hooks/_bash_guard_cmd.sh` (new),
`_bash_guard_lib.sh`, `_read_only_roots.sh`, `bash_guard.sh`, `dispatch_limit.sh`,
`precompact.sh`, `.agents/checks.toml`, `.factory-version`, and in packages
`.github/workflows/Benchmark.yml`. It also writes `scripts/_common.jl`, `scripts/gen.jl` and
`scripts/check_docs.jl` (which treats `.agents/factory.local.toml` as external); these are T3
once 0.2.2's `risk.toml` edit is made. And it writes `scripts/test/{runtests,test_hooks,
test_bash_guard,test_gen,test_sync_factory}.jl`. It seeds `LICENSE` where missing. Then, by
hand (T3: the user, or `FACTORY_ALLOW_T3=1`), run `julia scripts/gen.jl` and:

- every repo, `.gitignore` (seeded): add `/.agents/factory.local.toml` and
  `/.claude/hooks/read-only-roots.txt`, then `git rm --cached .claude/hooks/read-only-roots.txt`.
- every repo, `risk.toml`: add `".agents/factory.local*"` to the T3 globs.
- the coordinator, `.agents/factory.toml`: move the `read_only_roots` entries into a new
  `.agents/factory.local.toml` (`[bash_guard] read_only_roots = [...]`), set
  `read_only_roots = []` and add `require_read_only_roots = true`. Then run `julia scripts/gen.jl`.
- a seeded `LICENSE`: replace `<YEAR>` and `<COPYRIGHT HOLDER>` (packages that already had one
  keep theirs).

## 0.2.2 (2026-10-19)

Fixes found by the three package scaffolds (ChuiCore, ChuiTypes, ChuiFrames) and the coordinator
review (S2). Template tests: 807/807 on Julia 1.13.2 and 1.10.12 (683 in 0.2.1); each new test
fails against the 0.2.1 code. New T3 paths and a new contract-test environment: read the
migration notes.

- **`ratchet.jl` passes again (it failed in every repo).** `bash_guard.sh` (210 lines) was over
  the seeded 150-line hook budget. Its helpers moved to two new sourced libraries,
  `.claude/hooks/_bash_guard_lib.sh` (command splitting, paths, `rm`) and `_read_only_roots.sh`
  (bash_guard 142 lines, the libraries 115 and 61, `_lib.sh` 103), instead of a per-file
  exception: a `.` source costs no fork, a per-file rule would be a raised limit, and the
  read-only-roots parsing now runs in bash_guard only, not on every write_guard/dispatch_limit/
  advisory call. The command splitter is one awk instead of sed + tr. New test: every profile's files, as sync renders
  them, pass the seeded `ratchets.toml`.
- **Guards fail closed when a sourced library is missing.** `. _lib.sh` on a missing file exits
  1, which Claude Code treats as non-blocking: bash_guard, write_guard and dispatch_limit now
  check their libraries and exit 2.
- **bash_guard: quoted text is one argument.** `sed -i '' -e 's/<Package>/X/g' f` was read as a
  redirect to `/X/g`, and `git commit -m "a; rm -rf x"` as a second command. Inside `'...'`,
  `"..."` and `$'...'` (and after a backslash) blanks, `; & | ( ) < >` no longer split or
  redirect. A `"$(...)"` or backtick substitution inside double quotes is still split and checked,
  and a `#` comment ends its line (an apostrophe in it is not a quote). Real redirects of quoted
  paths (`> "/opt/x"`) are still caught. A `sh -c '...'` string is not inspected (it was caught
  in 0.2.1 only by accident, since `;` split everywhere).
- **bash_guard: `rm -rf` on scratch paths** (lanes could not clean their scratchpads). Allowed only
  when every target is ABSOLUTE (or `$TMPDIR/...`, `"$TMPDIR"/...`) and lies strictly below
  `$TMPDIR` or at least three levels below this user's `/private/tmp/claude-<uid>/` (a
  `<project>/<session>/...` path, no glob in those two parts). Never a relative target (the
  tracked cwd can be wrong after a bare `cd`, `cd -`, a subshell or `popd`), never in the repo
  root, never `$TMPDIR/...` when the command assigns TMPDIR, never another uid.
- **`ci.jl docs`, `jet` and `contracts` never rewrite tracked files.** They developed the
  checkout into `docs/` and `test/jet/` in place; on Julia >= 1.11 that wrote
  `[sources] Pkg = {path = "/abs/..."}`, added the package to `[deps]` and dropped comments
  (reproduced on a ChuiCore copy). They now copy the env's `Project.toml` to a scratch directory
  (relative `[sources]` paths made absolute), develop there, run there and delete it. Test: a
  fixture package's tracked files are byte-identical and `git status` clean after all three jobs.
- **Contract tests run in their own environment** (the coordinator's `contracts/README.md`): new
  seeded `test/contracts/Project.toml` (Test, TestItemRunner; upstreams added per repo) and
  `test/contracts/runtests.jl` (`TestItemRunner.run_tests` over `test/contracts/`, `:contract`
  items only). `ci.jl contracts` resolves a scratch copy against the latest upstream release, or
  upstream main with `-- main`, so the old `--in-place` gate is gone. A repo without
  `test/contracts/Project.toml` is skipped with a message. The seeded `test/runtests.jl` never
  selects `:contract` items, even with `-- all`.
- **Package profile overlay** `profiles/package/.agents/factory.toml`: `[check_docs] exclude =
  ["docs/agent/*", "test/contracts/*.md"]` for the verbatim copies every package carries.
- **Seeded `.gitignore`** ignores `/test/jet/Manifest*.toml` and `/test/contracts/Manifest*.toml`
  (`/docs/Manifest*.toml` was already there). Test: every seeded env directory's Manifest is ignored.
- **Seeded `test/jet/Project.toml`** has `[compat]` for TOML and `julia = "1.12"` (ADR-0004 rule 3).
  Test: every seeded `Project.toml` has compat for `julia` and each dep.
- **CI.yml: no Codecov upload.** ADR-0011 wants a local floor and no external service; the
  existing `ci.jl coverage` step (`ratchet.jl --lcov`, floor in `ratchets.toml`) is the check.
  ADR-0011 (Proposed) names a coverage-floor.txt file read by a coverage_floor.jl script; the
  factory keeps the floor in `ratchets.toml` (same one-way rule, one file). The ADR text should
  follow at its ★.
- **Protected paths (S2).** The seeded `risk.toml` makes `.agents/bodies/*`, `.agents/checks.toml`,
  `.claude/agents/*`, `.codex/agents/*` and the gate scripts (`scripts/dod.jl`, `ratchet.jl`,
  `gen.jl`, `check_docs.jl`, `contract_usage.jl`, `ci.jl`, `_common.jl`) T3. New coordinator
  overlay `profiles/coordinator/risk.toml`: the coordinator's current `risk.toml` plus the same
  globs. Its `adr` comment is profile-neutral (it named `docs/adr/`).
- `checks.toml`: bash_guard blind spots updated (quoting, the scratch `rm -rf` rule, edited
  libraries are trusted).

Review (one read-only reviewer over this diff) found three bash_guard bypasses that the first
draft of this release introduced, all fixed above with tests: a `"$(...)"` substitution was masked
as quoted text, an apostrophe in a `#` comment masked every later line, and the scratch `rm -rf`
rule trusted the tracked cwd and `$TMPDIR` (`cd /scratch/x && cd && rm -rf *` passed). Also
fixed from it: `$'...'` quoting, the rule naming every session's scratch, `"$TMPDIR"/x` blocked,
the test now proves the scratch envs are deleted, and `ci.jl test -- contract` says where
contract items run.

### Migration from 0.2.1 (seeded files are not updated by sync)

The sync writes these T3 files: `.claude/hooks/_bash_guard_lib.sh` and `_read_only_roots.sh` (new), `_lib.sh`,
`bash_guard.sh`, `dispatch_limit.sh`, `write_guard.sh`, `.factory-version`, and in packages
`.github/workflows/CI.yml`; plus `.agents/checks.toml` and `scripts/ci.jl`, which are T3 once
the `risk.toml` edit below is made. It seeds `test/contracts/Project.toml` and
`test/contracts/runtests.jl` in packages (T2). Then make these edits by hand (T3: the user, or
a session with `FACTORY_ALLOW_T3=1`), and run `julia scripts/gen.jl`:

- every repo, `risk.toml`: add the 11 globs above to the T3 `[[protected]]` list and reword the
  `adr` comment. The coordinator can take `factory/profiles/coordinator/risk.toml` as is (it is
  its current file plus these lines); an untailored package `risk.toml` can take
  `factory/template/risk.toml` as is.
- packages, `.gitignore`: add `/test/contracts/Manifest*.toml` (and `/test/jet/Manifest*.toml`
  if missing).
- packages, `test/jet/Project.toml`: under `[compat]` add `TOML = "1"` and `julia = "1.12"`.
- packages, `test/runtests.jl`: first line of the filter, `:contract in ti.tags && return false`.
- packages, `test/contracts/Project.toml`: add each upstream of `upstreams.toml` to `[deps]` with
  a `[compat]` bound before its contract tests are written.
- packages synced from 0.2.1 whose `.agents/factory.toml` lacks
  `exclude = ["docs/agent/*", "test/contracts/*.md"]`: add it (ChuiCore, ChuiTypes and
  ChuiFrames already have it).

## 0.2.1 (2026-10-19)

Fixes found running the 0.2.0 tests in the coordinator checkout (540 passed, 2 failed,
2 errored, 1 broken there; 665/665 in `factory/template`), plus the first review of the 0.2.0
contract-usage check (S6). No hook, `settings.json` or workflow changes: the only T3 file a
0.2.0 → 0.2.1 sync writes is the sync record `.factory-version` (every sync does).

- **Tests are hermetic across profiles.** The "package profile seeds no roots" hook test uses its
  own empty roots file instead of the checkout's generated `read-only-roots.txt` (the
  coordinator's lists a read-only reference repo). The repo-wide `check_docs.jl` run and the template's
  `test/contracts/` checks (seeded `USED.md` lists nothing, `upstreams.toml` has
  `[contract_files]`) run only in `factory/template`; a vendored repo already runs both
  scripts on itself in `ci.jl guards`, under its own settings.
- The sync tests no longer report a `@test_skip` ("Broken") in a vendored repo: not running
  there is by design (they test the factory's own copy, which the vendored one matches by hash),
  so an `@info` line says so.
- `check_docs.jl`: in a checkout holding the factory (`factory/MANIFEST.toml`), the backticked
  paths of `factory/*.md` also resolve against `factory/template/` (they name template paths
  such as the template's ADR directory). Removes 4 stale references in the coordinator without
  excluding the factory docs. New blind spot recorded in `.agents/checks.toml`.
- `sync_factory.jl`: a file recorded as managed that the factory now seeds is reported as
  `now-seeded` (it leaves the managed record) instead of `removed-upstream`. Like any seeded
  file it is not updated afterwards, even if the repo never edited it; its `seeded-differs`
  diff shows what the factory's version would change.
- `test_ci.jl`: a checkout without `.factory-version` takes its profile from its shape
  (`factory/MANIFEST.toml` present → coordinator) instead of always `package`.
- **`contract_usage.jl` (review of 0.2.0's S6; each was a false pass):** upstreams named only in
  `[contract_files]` (no URL yet) are grepped too; a commented-out `@testitem` (`#` or
  `#= =#`) is not a test; an ID-named test item without `tags = [:contract]` is an error
  (`ci.jl contracts` runs only those). Also: `Up.:(⨟)` and `using Up: (⨟)` are recognised;
  `#= =#` blocks in code are skipped; `status=stable-ish` is invalid; a fence closes only on its
  own character; a `# ` heading ends an entry; an ID with two entries is an error.
- `check_docs.jl`'s second root applies to backticked paths only, not to Markdown links.
- `/contract-check` names `--contracts`, the upstreams grepped, and a fix for every error the
  script reports; new blind spots (module aliases, docstring mentions, tags on a later line).
  The `contract_steward` body mentions `USED.md` and `contract_usage.jl`, and drafts request
  text instead of writing to the coordinator's `requests/`.

Coordinator follow-ups outside the factory (repo-owned): `.agents/bodies/coord_architect.md`
and `adr/README.md` named the package ADR directory as a repo path; reworded and regenerated.

## 0.2.0 (2026-10-19)

Fixes found while vendoring the coordinator profile.

- **Read-only roots (stricter guard).** `bash_guard.sh` denies any command that would RUN in a
  directory listed in `.agents/factory.toml [bash_guard] read_only_roots`, except cat, head,
  tail, less, grep, rg, find (no -exec/-delete), ls, wc, stat, file, cd/pwd and git
  log/show/diff/status/blame/ls-files. The run directory is the payload cwd, a tracked
  `cd`/`pushd`, `git -C`, `make -C/--directory`, `uv --directory/--project`, or
  `julia --project=`. Catches the 2026-10-19 incident
  (`cd <a read-only reference repo> && uv run ...`). The package profile seeds no roots; the
  coordinator seeds its three read-only reference repos.
- Review fixes (in the same release): `2>&1`/`>&2`/`&>` are no longer split as command
  separators; `git -c a=b -C dir ...` and `git --no-pager -C dir ...` are seen by both the
  read-only and the outside-root checks, and the denylist sees through git global options
  (`git -c x=y reset --hard` is blocked); `cd -P/-L dir`, `env -C dir` / `env --chdir=dir` are
  followed; read-only roots match case-insensitively (APFS); an indented closing fence closes in
  check_docs; `.agents/factory.toml` value types are validated; `dod.jl --adr-dir` works even
  with an unreadable `.factory-version`; sync repairs a mode-only difference.
- `cd` is now tracked across segments for the outside-the-root write check too
  (`cd /outside && touch f` is blocked), and `git -C dir --no-pager log` is recognised as
  read-only. `normpath` in `_lib.sh` no longer turns globbing back on inside the guard.
- **Guards fail closed** when their script is missing: `settings.json` wraps bash_guard,
  write_guard and dispatch_limit in `sh -c '...'` that exits 2 with a message.
- New seeded, T3-protected `.agents/factory.toml` (per-profile defaults) and generated
  `.claude/hooks/read-only-roots.txt`.
- `check_docs.jl` reads `[check_docs]` from `.agents/factory.toml`: `exclude` globs,
  `external` globs of references allowed to be missing, `ignore_fenced`; plus `--config FILE`.
  The coordinator defaults exclude `research/**`, `reference/**`, `prompts/**`, numbered ADRs
  (`adr/0*`) and `factory/template/**`, allow package paths (`docs/agent/*`, `test/*`, `src/*`,
  `ext/*`, `benchmark/*`) and `.claude/worktrees/*`, and ignore fenced blocks (172 stale
  references on the coordinator before, 0 after).
- MANIFEST profiles gain `overlay` and `adr_dir`. The coordinator profile uses
  `profiles/coordinator/` and `adr_dir = "adr"`, and no longer takes `docs/adr/*` (its `adr/`
  is their source). `.factory-version` records `adr_dir`; `dod.jl` checks ADRs there
  (`--adr-dir` overrides).
- `scripts/test/test_ci.jl` is profile-aware: the template and package profile still require
  every ci.jl job to be called; a coordinator checkout requires the workflows it was given to
  exist and call ci.jl, and `guards` to be called.
- **Contract usage by ID (S6), in the format of contracts/README.md.** New
  `scripts/contract_usage.jl [--contracts DIR] [--strict]`, run by `ci.jl guards`; seeded
  `test/contracts/USED.md` (`- <ID> [— note]` lines; package profile); `upstreams.toml` gains
  `[contract_files]` (vendored copies of the upstream contract files, so a fresh clone checks
  itself). Errors: a listed ID without exactly one `@testitem "<ID> ..."`, a contract test item
  for an unlisted ID, `@test_skip`/`@test_broken` in a contract test, an ID missing from the
  contract files or `status=retired`, a used upstream name whose `names:` line maps to an
  unlisted ID, a used upstream without a contract file. Warnings: `status=deprecated`, a used
  name no stable/deprecated `names:` line covers (an error with `--strict`). `/contract-check`
  refreshes the contract files and runs it with `--strict`. Skipped without USED.md (coordinator).
- Denials from a session rooted in `factory/template` say that the template's hooks apply.
  README: profiles, "start sessions and dispatch lanes from the repo root", and how a first
  vendoring writes T3 files.

Migrating from 0.1.0: the sync seeds `.agents/factory.toml`. Seeded files are never updated,
so an existing `risk.toml` does not gain the new T3 glob `.agents/factory.toml`; add it by hand
(T3 edit). In the coordinator, the 0.1.0 copies under `docs/adr/` are reported as
removed-upstream and are not deleted; remove them by hand.

## 0.1.0 (2026-10-19)

- First version, built in Phase L0 from the study in `research/reference-projects.md`.
- Agent registry with 12 roles, prose bodies, `scripts/gen.jl` (`--check`) generating
  Claude and Codex agent files, `AGENTS.md`, the PR template, protected paths, lane limits and
  `docs/CHECK_COVERAGE.md`.
- Hooks (POSIX sh + jq): bash_guard, write_guard, dispatch_limit, lane_ledger,
  teammate_idle, precompact, session_start; wiring in `.claude/settings.json`.
- Commands: intake, lanes, change-review, contract-check, release-check, test-changed; skill
  lane-lifecycle.
- Scripts: lane (worktrees at `<repo>/.worktrees/<lane>`), dod, ratchet, check_docs, ci, bench,
  sync_factory; tests for every script and hook in `scripts/test/`.
- Workflows: CI (lts/stable/pre matrix, coverage, quality, Runic), Docs, Contracts
  (release blocks, main warns), Benchmark, Guards (generated files, ratchets, doc references,
  factory tests, definition of done), CompatHelper, TagBot.
- JET in its own `test/jet/` environment (stable only); doctest/snapshot items stable only.
