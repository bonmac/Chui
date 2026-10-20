# Who owns `missing`-aware aggregators (`skipmissing` variants)? (R8)

- **From → to:** chui-frames → chui-core
- **Status:** rejected        <!-- answered: option A, ChuiFrames owns them (user, 2026-10-20) -->
- **Urgency:** soon (ChuiFrames phase 2 implements `sum(skipmissing(c.x))`, ChuiFrames ADR-0002 rule 10)
- **Contract IDs affected:** PROVISIONAL ("`missing`-aware aggregators" in `chui-core.md`); CC-004, CC-006, CC-007 if ChuiCore owns them
- **Adapter used meanwhile:** a local wrapper aggregator in ChuiFrames' internal upstream adapter (ChuiFrames ADR-0014 §1, §4; the module is not yet on ChuiFrames main c5db1cb)
- **Reproducer:** only if ChuiCore takes ownership (option B below), with the ChuiCore snapshot under test: `julia --startup-file=no -e 'using ChuiCore, Test; const CC = ChuiCore; m = CC.SkipMissingM(CC.Sum()); @test CC.final(m, CC.partial(m, CC.init(m), [1, missing, 2])) == 3; @test CC.final(m, CC.partial(m, CC.init(m), [missing])) == 0; mx = CC.SkipMissingM(CC.Max()); @test_throws ArgumentError CC.final(mx, CC.partial(mx, CC.init(mx), [missing]))'` (`SkipMissingM` is a placeholder name). RED today: no ChuiCore snapshot. GREEN on 1.10.12 and 1.13.2. Under option A the request closes as `rejected` with the decision, and needs no reproducer. Not run by this lane.

## Problem
ChuiFrames makes `skipmissing(c.x)` a node valid only as a reduction's argument
(`sum(skipmissing(c.x))`); reductions otherwise propagate `missing` (ChuiFrames ADR-0002 rule 10).
The engine evaluates every reduction through the upstream adapter's aggregators so that CC-006 and
CC-007 hold on both paths (ChuiFrames ADR-0003 rule 7). So each supported reduction needs a
`missing`-skipping aggregator.

ChuiFrames' release gate fails while a stand-in remains for a piece **ChuiCore owns** (ChuiFrames
ADR-0014 §5). Whether these aggregators are such a piece is undecided, so ChuiFrames cannot tell
whether its wrapper is permanent or a stand-in.

## Proposed API
The question, with two answers ChuiFrames can work with:
- **(A) ChuiFrames owns them** (recommended by this lane; matches ecosystem ADR-0002 §2's text).
  ChuiFrames builds a wrapper aggregator on CC-004, in its own code, with no ChuiCore change. It is
  not a stand-in, so ChuiFrames ADR-0014 §5's gate does not apply. ChuiCore records the decision
  in `chui-core.md`'s PROVISIONAL bullet, which the lead then removes.
- **(B) ChuiCore owns a generic wrapper**, `SkipMissingM(inner)` (placeholder; `Base.SkipMissing`
  is a Base type, unexported on 1.10.12 and 1.13.2), public, not exported, beside `MapM`:
  - `partial` skips `missing` elements of the chunk and delegates the rest to `inner`;
  - `init`, `combine`, `final` and `iscommutative` are `inner`'s;
  - input that is empty after skipping follows `inner`'s CC-006 row (`Sum` → 0, `Max` → CC-007's
    `ArgumentError`);
  - it passes `test_aggregator_laws` with CC-004's tolerance.

## History
- 2026-10-20 open: drafted in the ChuiFrames phase-1 report (ChuiFrames ADR-0002 rule 10,
  ADR-0014 §4; main c5db1cb); filed by the coordinator lane frames-reqs for the lead.
  **Partly answered at filing:** ecosystem ADR-0002 §2 says "ChuiFrames builds column- and
  `missing`-aware aggregates *on top* of it [CC-004] and does not redefine it", and
  `chui-core.md`'s PROVISIONAL bullet repeats that "whether any live in ChuiCore is open".
  ChuiCore's accepted ADRs 0001–0008 do not mention `missing` or `skipmissing`.
- 2026-10-20 rejected (answered): the user chose **option A** at the ChuiFrames contract ★.
  ChuiFrames owns its `missing`-aware aggregators, built on CC-004 in its own code; they are not
  a stand-in, so ChuiFrames ADR-0014 §5's release gate does not apply. ChuiCore changes nothing;
  the PROVISIONAL bullet in `chui-core.md` is removed at the next contract edit.
