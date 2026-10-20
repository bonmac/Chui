# ADR-0013: Effect–Task adapters keep the exception object and the cancellation, not Base `fetch`'s shape or the `Die`/`Fail` kind

- **Status:** Accepted (2026-10-20, user at the contract ★; the wording was accepted at the
  ChuiTypes phase-1 ★). The user applies the T3 edit to `contracts/chui-types.md`.
- **Date:** 2026-10-20
- **Deciders:** the user (contract files are T3, `risk.toml`)
- **Scope:** ecosystem (contract ADR for `contracts/chui-types.md`, ADR-0010)

## Context

`contracts/chui-types.md` obligation 2 ("Conversions to and from the runtime live in ChuiTypes")
promises three things that ChuiTypes ADR-0006 (accepted 2026-10-20) found impossible or ambiguous:

- **(B1) Effect → Task:** "an effect failure is thrown from `fetch` as the original exception".
  Base's `fetch` on a `Task` always throws `TaskFailedException`, even when the body rethrows; the
  original is at `e.task.exception`. This was observed on 1.13.2 and 1.10.12 (ChuiTypes evidence
  EFF-05, `crit-fetch10-*`: `fetch threw: (TaskFailedException, true)`).
- **(B2) Cancellation:** "cancelling the effect stops the task". A started foreign `Task` cannot
  be stopped from outside. It captures scoped values at construction (EFF-09), opaque code such as
  `read` checks no token, and `throwto` corrupts running tasks (EFF-04). Obligation 1's future
  test repeats the claim.
- **(C3) Round trip:** "same failure" and "error channel" are undefined. The runtime's error
  channel is a `Cause` (`Fail(e)`, `Die(ex, bt)`, `Interrupted`; ChuiTypes ADR-0002 §3). A Base
  `Task` has no defect/error distinction, so a `Die` that crosses a Task boundary comes back as a
  `Fail` (ChuiTypes ADR-0006 §4).

Obligations have no IDs and no contract tests (`contracts/README.md`). Since the contract became
binding (2026-10-19), every change to the file still needs an ADR (ADR-0010). Nothing downstream
relies on obligation 2 yet: ChuiTypes' adapters are designed, not built (ChuiTypes ADR-0006,
Verification).

## Decision

1. Obligation 2's semantics **must** be restated as ChuiTypes ADR-0006's Consequences word them.
   - **B1.** `fetch` on the `Fiber` handle throws the original exception. On a Base `Task` from
     `totask`, `fetch` throws `TaskFailedException` with `task.exception === original`.
   - **B2.** Cancelling a `fromtask(t::Task)` effect runs its canceller. Without a canceller, it abandons
     the task and counts it as an orphan.
   - **C3.** The error channel is the `Cause`. The round trip keeps the success value, the
     exception object and the cancellation, but a `Die` comes back as a `Fail`.
2. Obligation 1's future-test sentence on cancellation **must** say the same as B2.
3. The illustrative block uses ChuiTypes ADR-0006's accepted names (`fromtask`, `run`) in place of
   the `from_task` placeholder. It is still parsed, never run.
4. Both stay **obligations**: there are no IDs until the adapters are built and their names
   released (ChuiTypes phase 3).

**Exact replacement text** for `contracts/chui-types.md` (T3).

(a) Obligation 1: replace the last two lines of its "Future test" bullet (from "converts to, the
runtime's effect type" to "cancels the underlying `Task`.") with:

```markdown
  converts to, the runtime's effect type and runs through its run function; cancelling it through
  the runtime runs its canceller, or abandons and counts a foreign `Task` that has none
  (obligation 2, ADR-0013).
```

(b) Obligation 2: replace the bullet "Semantics every adapter keeps:" and its five sub-bullets with:

```markdown
- Semantics every adapter keeps (amended by ADR-0013, from ChuiTypes ADR-0006). The **error
  channel** is the runtime's `Cause`: `Fail(e)`, `Die(ex, bt)` or `Interrupted` (ChuiTypes
  ADR-0002 §3).
  - *Task → effect:* running the effect runs the task (once; later runs see the same outcome)
    and succeeds with the task's value. If the task fails, the effect fails with `Fail(ex)`, where
    `ex` is the task's own exception object (`task.exception`), never the
    `TaskFailedException`. **Cancelling** a `fromtask(t::Task)` effect runs its canceller if
    one was given, then awaits the task. Without a canceller the effect ends `Interrupted` at
    once, and the task is **abandoned** and counted in the runtime's orphan counter: a started
    foreign `Task` cannot be stopped from outside. (`fromtask(f::Function)` runs `f` as
    cooperative work under the effect's cancel state and awaits it on cancellation.)
  - *Effect → Task:* the task's result is the effect's success value. `fetch` on the returned
    **`Fiber`** handle throws the original exception. A Base `Task` from `totask` cannot do
    that, because Base's `fetch` always wraps: its `fetch` throws a `TaskFailedException` whose
    `task.exception === original`. Cancelling the effect stops its task at the next step or
    runtime primitive.
  - *Exceptions:* a thrown exception inside an effect becomes a value in the error channel (a
    `Die`); converting back through `run` or a `Fiber` rethrows the same exception object
    (`===`); through `totask`, Base wraps it as above.
  - *Channel ↔ effect/stream:* closing the channel ends the stream; an exception closing the
    channel becomes a stream failure.
  - *Round trip:* converting to the runtime and back keeps the success value, the exception
    object and the cancellation. It does **not** keep the `Die`/`Fail` kind: an exception that
    crosses a Task boundary always comes back as `Fail(ex)`, because a Base `Task` has no
    defect/error distinction.
```

(c) PROVISIONAL: replace the bullet "**The adapter names** behind the conversion obligation
(`from_task` and similar above are placeholders)." with:

```markdown
- **The adapter names** behind the conversion obligation. ChuiTypes ADR-0006 accepts
  `fromtask`, `totask`, `Fiber`, `fromchannel` and `tochannel`; they are not yet built or
  released, so there is no entry yet.
```

(d) Obligation 2: replace its "Future test" bullet and the illustrative block with:

````markdown
- Future test, once named: round-trips a successful `Task`, a failing `Task` (the exception object
  is preserved, `===`, and comes back as `Fail`) and a `Channel` (closing ends the stream) for
  each conversion the downstream uses; `fetch` on a `Fiber` throws the original exception, and
  on a `totask` Base `Task` a `TaskFailedException` whose `task.exception` is that object;
  cancelling a `fromtask(t::Task)` effect without a canceller ends it `Interrupted` and raises the orphan
  count by one.

Illustrative shape only (names from ChuiTypes ADR-0006, accepted but not yet built; parsed, never run):
```julia
using ChuiTypes
eff = ChuiTypes.fromtask(@task read("data.csv", String))   # Task → the runtime's effect type
res = ChuiTypes.run(eff)                                  # run on the one runtime
```
````

## Alternatives rejected

| Alternative | Why rejected |
|---|---|
| Keep "thrown from `fetch` as the original" and make `totask` return a Task that unwraps | Impossible: Base's `fetch` always wraps (EFF-05). |
| Keep "cancelling stops the task" and stop foreign tasks with `throwto` | It corrupts running tasks (EFF-04). |
| Wait uninterruptibly on a foreign task when there is no canceller | `timeout(fromtask(t), d)` would hang on a silent peer (ChuiTypes ADR-0006 §2). |
| Preserve the `Die`/`Fail` kind across Task boundaries | A Base `Task` carries only an exception; the kind would need a wrapper type that Base code does not know about. |
| Promote obligation 2 to a stable entry now | Its test needs built adapters; IDs are permanent (ADR-0010). |

## Consequences

- **T3 edit the user must authorize:** (a) to (d) above, in `contracts/chui-types.md`.
- **ChuiFrames' asynchronous I/O must pass cancellers** (for example, closing the file or socket)
  to be cancellable (ChuiTypes ADR-0006, Consequences).
- ChuiFrames carries a copy of `chui-types.md` under `test/contracts/`, which it refreshes in its
  own commit after the edit.

## Verification

- ChuiTypes ADR-0006 (main 455c085), its Verification section (EFF-04, EFF-05, EFF-09; `crit-fetch10-*`
  on both versions), and ADR-0002 §3 (`Cause`).
- The amended file was checked with `contracts/check.jl` in a scratch copy, alongside ADR-0012's
  `chui-core.md` text: 0 errors on 1.13.2 and 1.10.12 (28 julia blocks parsed, including the
  changed illustrative block).
- UNVERIFIED: none of these semantics run yet. The adapters are phase-3 work in ChuiTypes.

## Revisit when

- ChuiTypes ships the adapters: the obligations become entries with IDs and `test:` lines.
- Julia makes Base tasks cancellable, or `fetch` stops wrapping (ChuiTypes ADR-0006's trigger).
