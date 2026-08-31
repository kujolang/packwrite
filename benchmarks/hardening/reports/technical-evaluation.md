# PackWrite v1.1.0 Before/After Hardening Evaluation

## Executive summary

PackWrite v1.1.0 is materially safer, more deterministic, and more usable by
automation than its immediate pre-hardening predecessor, but it is not a
general performance optimization. The strongest improvement is a scaling fix
on malformed model output. At 64 KiB, the pre-hardening parser did not finish
within the five-second cap in any of 10 measured runs. Current completed with a
median of 565.7 ms (p95 665.8 ms). That is at least an 88.7% latency reduction
and more than an 8.9× speedup on the tested failure path. Kujo Eval improved
from 4/11 to 11/11 checks using the same suite.

The change also fixed a release-blocking compatibility defect: the unmodified
baseline cannot start on standalone Kujo 1.1.0 because `src.cli` collides with
the runtime's built-in module. Current starts normally. It adds bounded model
responses, semantic manifest limits, symlink/output containment, atomic private
raw-evidence writes, typed configuration validation, deterministic JSON and
quiet output, a read-only summary command, endpoint validation, a pinned CI
runtime, and much broader failure-path tests.

Those gains have costs. Successful 13-file generation slowed from 1.010 s to
1.555 s median (+54.0%); 64-file generation slowed from 5.343 s to 8.331 s
(+55.9%); validation slowed from 391.2 ms to 462.4 ms (+18.2%). Median peak RSS
for the 13-file workload increased 360,448 bytes (+2.24%). Source lines grew
18.6%, repository bytes grew 25.3%, rendered prompt bytes grew 7.0%, and
rendered context bytes grew 27.0%. The common success-path CLI output did not
shrink. Startup's apparent 1.1% improvement is below noise and is inconclusive.

No live provider was used. Therefore token consumption, cached tokens, dollar
cost, network calls, and end-to-end agent completion quality are **not
demonstrated**. Prompt bytes are reported as context-footprint evidence, not as
tokens. PackWrite remains interpreted and has zero declared direct package
dependencies, so PackWrite compile time and binary size are not applicable.

For maintainers, the evidence supports shipping v1.1.0 as a reliability and
boundary-hardening release. It does not support describing it as broadly
faster or leaner. For users, realistic malformed or hostile model responses
now terminate predictably, filesystem writes are better contained, automation
has machine-readable commands, and the released runtime actually works. Normal
generation is slower and slightly heavier.

## Evaluation boundary

| State | Commit | Timestamp | Tag/status |
|---|---|---|---|
| Baseline | `f63425187d39580b36032b1f31731e3f086db9f1` | 2026-08-23 16:48:16 -0400 | `refactor: streamline CLI output helpers` |
| Current | `b69652241b035a7216a59867d93073728849987e` | 2026-08-30 19:50:28 -0400 | v1.1.0 release commit |

`f634251` is the immediate parent of `149a004`, the first dedicated hardening
commit. The older v1.0.0 tag was considered but rejected as the primary
baseline because two ordinary maintenance commits occurred between that tag
and the start of hardening. Choosing v1.0.0 would incorrectly attribute those
changes to this pass.

The evaluated current state was `main` at the v1.1.0 tag and clean before the
evaluation artifacts were added. The baseline performance checkout received
only the documented compatibility patch described in the methodology. The
unmodified startup failure remains part of the result.

## Before/after scorecard

All latency values are medians across 10 measured runs after three warmups.

| Metric | Baseline | Current | Change | Assessment |
|---|---:|---:|---:|---|
| Kujo Eval | 4/11 (36%) | 11/11 (100%) | +7 checks, +64 pp | Clear improvement |
| Version/startup | 129.4 ms | 128.0 ms | -1.5 ms (-1.1%) | Inconclusive |
| Validate | 391.2 ms | 462.4 ms | +71.2 ms (+18.2%) | Regression |
| Generate, 13 files | 1.010 s | 1.555 s | +545.1 ms (+54.0%) | Regression |
| Generate, 32 files | 4.568 s | 5.548 s | +979.8 ms (+21.4%) | Likely regression |
| Generate, 64 files | 5.343 s | 8.331 s | +2.989 s (+55.9%) | Regression |
| Invalid response, 1 KiB | 501.0 ms | 567.9 ms | +66.9 ms (+13.3%) | Likely regression/noisy |
| Invalid response, 64 KiB | ≥5.015 s timeout | 565.7 ms | ≤-4.450 s (≥88.7%) | Clear improvement |
| Peak RSS, 13 files | 16,093,184 B | 16,453,632 B | +360,448 B (+2.24%) | Small regression |
| Success output, 13 files | 763 B / 23 lines | 763 B / 23 lines | 0 | Neutral |
| Prompt representation | 3,034 B / 69 lines | 3,247 B / 71 lines | +213 B (+7.0%) | Tradeoff |
| Repo-context representation | 230 B / 11 lines | 292 B / 12 lines | +62 B (+27.0%) | Tradeoff |
| Native test runs | 2/3 clean | 3/3 clean | +1 clean run | Observed reliability gain |
| Unit + CLI assertions | 191 | 248 | +57 (+29.8%) | More coverage; not a speed metric |
| Source lines | 2,916 | 3,459 | +543 (+18.6%) | Complexity increased |
| Test lines | 850 | 1,075 | +225 (+26.5%) | Coverage investment |
| Repository bytes | 225,189 | 282,092 | +56,903 (+25.3%) | Footprint regression |
| Direct dependencies | 0 | 0 | 0 | Neutral |

The baseline 64 KiB value is right-censored: five seconds is a lower bound,
not its completion time. The current completed diagnostic was 1,126 bytes;
the baseline's 292-byte sample is incomplete timeout output and must not be
presented as an output-efficiency win.

## What changed and why it matters

### Model-output parsing and resource limits

`149a004` replaced whole-response sanitization before preview extraction with
bounded head/tail extraction and added response, file-count, path, per-file,
and total-content limits. The old invalid-response path repeatedly processed
the full string and scaled pathologically. The new path bounds diagnostic work
and rejects oversized structures before later validation or writes.

Expected metric: failure latency, CPU work, output amplification, and memory.
Measured result: at 1 KiB current was slightly slower; at 64 KiB it completed in
0.566 s while baseline exceeded 5 s. The curve changes from already pathological
by 64 KiB to effectively bounded across the measured range. CPU allocation
profiles were not collected, so the mechanism-to-CPU claim is derived from
source and wall/user time, not direct allocation evidence.

### Filesystem containment and evidence writes

`149a004` and `61959a1` added lexical/canonical output checks, symlink-ancestor
rejection, clean replacement, private atomic raw-response writes, overwrite
refusal, control-character checks, and manifest semantic limits. The baseline
either lacked these boundaries or handled them after more work.

Expected metric: deterministic failure, absence of redirected writes, evidence
preservation, and fewer partial states. Measured result: current passed nested
output, symlink containment, and raw-evidence preservation Eval checks; baseline
failed all three. These are behavioral wins, not latency wins.

### Typed configuration and endpoint validation

Configuration now rejects wrong types instead of allowing them to flow into
string/boolean operations; doctor validates endpoint form and returns stable
strict JSON failure semantics. The baseline wrong-type case triggers a Kujo VM
`int + string` runtime error. Current returns a controlled application error.

Expected metric: crash avoidance and diagnostic quality. Measured result:
current passed both corresponding Eval checks; baseline failed.

### Agent-facing commands and output modes

`61959a1` added `summary`, `--json`, and `--quiet` paths plus deterministic
machine-facing responses. Common human output stayed byte-for-byte identical
for version, validate, and the 13-file dry run. The benefit is selectable,
structured output rather than automatic output reduction.

Expected metric: parsing reliability and agent/tool usability. Measured result:
current's summary JSON passed shape validation; baseline lacked the command.
Agent turns, tool calls, completion rate, and context growth were not measured
with a live agent, so reductions in those metrics are inferred, not demonstrated.

### Standalone runtime and CI

`7e7b13a` renamed the command module and embedded its small parser so the release
does not depend on a source-only runtime module. `bf1fe3a` and `721cc14` pinned
and refreshed the CI runtime. Unmodified baseline fails at startup on Kujo 1.1.0;
current runs. For fair performance comparison, the same compatibility behavior
was applied to the disposable baseline without carrying over hardening logic.

## Runtime and scaling analysis

| Workload | Baseline p50 / p95 | Current p50 / p95 | Stddev baseline / current | n |
|---|---:|---:|---:|---:|
| Version | 129.4 / 135.6 ms | 128.0 / 162.5 ms | 3.6 / 12.3 ms | 10 each |
| Validate | 391.2 / 433.1 ms | 462.4 / 501.4 ms | 17.5 / 29.1 ms | 10 each |
| Generate 13 | 1.010 / 1.191 s | 1.555 / 2.025 s | 0.098 / 0.176 s | 10 each |
| Generate 32 | 4.568 / 5.876 s | 5.548 / 6.443 s | 0.500 / 0.533 s | 10 each |
| Generate 64 | 5.343 / 6.182 s | 8.331 / 9.404 s | 0.427 / 0.610 s | 10 each |
| Invalid 1 KiB | 501.0 / 552.9 ms | 567.9 / 910.8 ms | 25.1 / 119.5 ms | 10 each |
| Invalid 64 KiB | 5.015 / 5.021 s capped | 565.7 / 665.8 ms | 3.6 / 36.7 ms | 10 each |

p99 equals the maximum with 10 samples and is therefore not independently
informative; raw samples remain in `results/hyperfine`. Throughput is the
reciprocal of latency for these single-operation serial workloads. No concurrent
PackWrite server or batch queue exists, so sustained operations/second would be
an artificial metric.

Generation does not show an improved success-path scaling curve. Current is
slower at 13, 32, and 64 files, consistent with additional per-entry semantic
and containment checks. The malformed-input curve does improve decisively:
the advantage appears only once input becomes large enough to trigger the old
full-string behavior. This is why the 1 KiB workload alone would have produced
the wrong conclusion.

## Token, context, tool, and cost efficiency

The offline seam made zero model and network calls. Input, output, cached,
prompt, and completion tokens are **not demonstrated**. No dollar savings are
estimated. Byte measurements show the opposite of context compression on the
fixed probe: prompt bytes rose from 3,034 to 3,247 and context bytes from 230
to 292. The added text establishes untrusted-data boundaries and context
warnings; it is a deliberate safety tradeoff.

Tool output was unchanged on successful common operations. The completed
64 KiB failure emits 1,126 bytes, within the 2 KiB Eval bound. Baseline emitted
only 292 bytes before forced termination, so no output-reduction percentage is
valid there. Current adds JSON/quiet modes that can reduce downstream parsing
and irrelevant context when selected, but actual agent cycles and tool calls
remain unmeasured.

## Memory, build, artifacts, and dependencies

Ten `/usr/bin/time -l` runs of the 13-file dry run produced median peak RSS of
16.09 MB baseline and 16.45 MB current. The 2.24% increase is small and the
ranges overlap (15.85–16.43 MB versus 16.26–16.87 MB), so it is a likely small
regression rather than a high-confidence architectural change. Steady-state
memory and allocation counts were not available for this short-lived process.

PackWrite is interpreted. There is no PackWrite clean/incremental/release build
or PackWrite binary to compare. Both commits declare zero direct package
dependencies. The same 27,688,572-byte Kujo 1.1.0 runtime binary executed both
states, so runtime artifact size is controlled rather than an outcome. The
repository itself grew 25.3%, primarily through hardening logic, docs, CI, and
golden fixtures.

## Complexity and maintainability

Source functions increased 148→165 (+11.5%) and branch/loop/exception tokens
increased 436→553 (+26.8%). Complexity was not removed; it was added at trust
boundaries and in agent-facing modes. Some duplication was consolidated into
output helpers and a local parser, but the net codebase is larger. Maintainability
improves in explicit contracts, predictable envelopes, release compatibility,
and 57 additional assertions; it regresses in raw surface area. No cyclomatic
analyzer exists for Kujo, so branch-token counts are a proxy, not true
cyclomatic complexity.

## Reliability and deterministic behavior

The shared Kujo Eval suite exercised minimal, typical, nested-output, malformed,
oversized, overwrite, JSON, doctor, and symlink cases. Baseline passed the three
common operations and the runtime-level oversized-read bound (4/11). Current
passed 11/11. Eval's generated report labels the suite version `0.0.0` despite
the source definition's `1.0.0`, and its built-in compare expected a
`last_run.json` artifact the installed Eval did not emit. The preserved summaries
are the authoritative actual scores; no score was invented to replace them.

Native version-specific suites were run three times. Baseline had one intermittent
CLI failure (`prompt codex-review missing content`) and two clean runs; current
had three clean runs at 182 unit + 66 CLI assertions each. Current's suite takes
longer, but it executes 29.8% more assertions and is not the same workload, so
that duration is not classified as a performance regression.

## Change-to-result mapping

| Commit | Change | Intended effect | Observed effect |
|---|---|---|---|
| `149a004` | Bounded previews/limits, path and write guards, typed checks | Bound untrusted model/file behavior | 64 KiB failure >5 s→0.566 s; multiple boundary Evals pass |
| `c706c7a` | Hardening audit documentation | Preserve rationale and open evidence | No runtime effect measured |
| `bf1fe3a` | Pinned Kujo runtime in CI | Reproducible CI | Configuration observed; CI variance not benchmarked |
| `61959a1` | JSON/quiet/summary, follow-up guards and tests | Agent usability and deterministic diagnostics | Summary/doctor Evals pass; common output unchanged |
| `7e7b13a` | Self-contained parser and module rename | Standalone release compatibility | Baseline fails startup; current succeeds |
| `721cc14` | Runtime pin refresh | Align CI with released runtime | Controlled runtime available; no independent speed effect |
| `b696522` | Version/docs/release preparation | Ship v1.1.0 consistently | Version/tag consistency observed; no performance effect |

The normal-generation regression maps primarily to the added semantic/path
checks in `149a004` and the extra command/config branching in `61959a1`. The
memory and prompt increases are the corresponding footprint tradeoffs.

## Top improvements

1. **Large malformed-output latency is bounded.** More than an 8.9× measured
   lower-bound speedup prevents a realistic model failure from consuming the
   process indefinitely.
2. **Standalone release compatibility is restored.** Current starts on the
   released runtime; unmodified baseline does not.
3. **Behavioral boundary coverage rises from 4/11 to 11/11.** Writes, symlinks,
   raw evidence, typed config, and JSON failure behavior are now deterministic.
4. **Native reliability and coverage improve.** Three current runs passed 248
   assertions; baseline produced one intermittent failure and had 191 assertions.
5. **Automation surfaces are explicit.** Summary, JSON, quiet, and strict doctor
   modes eliminate ad-hoc human-output parsing when callers opt in.

## Regressions and tradeoffs

| Metric | Baseline | Current | Severity | Likely cause | Action |
|---|---:|---:|---|---|---|
| 13-file generation | 1.010 s | 1.555 s | Medium | Additional parsing/path/semantic checks | Profile before changing safety logic |
| 64-file generation | 5.343 s | 8.331 s | High for large packs | Repeated containment and validation work | P1: profile per-file checks and duplicate passes |
| Validation | 391.2 ms | 462.4 ms | Low/medium | Stronger output-location validation | Accept unless idle-host rerun confirms larger impact |
| Peak RSS | 16.09 MB | 16.45 MB | Low | Extra structures and validation | Monitor; overlapping ranges |
| Prompt/context bytes | 3,034/230 | 3,247/292 | Low | Explicit trust-boundary instructions | Accept unless token tests show quality-neutral compression |
| Source/repository footprint | 2,916 lines / 225 KB | 3,459 / 282 KB | Medium maintainability cost | Safety, modes, docs, fixtures | Keep contracts; seek consolidation only with tests |

No data supports claiming “no regressions.” The regressions above are
operationally meaningful even though the reliability trade is favorable.

## Remaining opportunities

- **P1:** Profile current 13–64-file manifest validation and output containment.
  Evidence shows 21–56% slower medians and suggests repeated per-file work.
- **P1:** Add a tokenizer/provider-instrumented offline or recorded Eval to
  measure token, cached-token, context, and completion-quality effects.
- **P2:** Re-run latency on an otherwise idle host; preserve this shared-host
  run as the realistic contention case.
- **P2:** Add a Kujo-native allocation/CPU profile once runtime tooling exposes
  it, especially around string scanning and canonical path checks.
- **P2:** Fix or document Kujo Eval's suite-version/report-manifest drift and
  missing `last_run.json` compare contract in the Eval repository; this is a
  cross-repository follow-up, not modified here.
- **P3:** Consider a compact trust-boundary prompt variant only after an Eval
  proves unchanged pack quality.

## Benchmark methodology

Environment: macOS 26.3.1 (Darwin 25.3.0), x86_64 Intel Core i7-9750H,
6 physical/12 logical cores, 16 GiB RAM, Kujo 1.1.0, Rust/Cargo 1.96.0,
Hyperfine 1.20.0. The filesystem had 23 GiB available and was 95% utilized.
All AI workloads used the same local fake-response seam: no key, provider,
model, network, retry, or cache variability.

Each paired runtime benchmark used three warmups and 10 measured runs. Reports
use median; min, max, mean, standard deviation, p95, and raw samples are stored.
p99 is retained machine-readably but equals the maximum at n=10. Peak RSS used
10 measured runs. Native tests ran three times. Eval used the same 11 checks,
repeat 3, and seed 20260830 for both states.

Known limitations: unrelated jobs were active on the shared host; small deltas
are treated conservatively. The 64 KiB baseline was capped at five seconds.
The compatibility patch makes non-startup performance measurable but removes
the release-startup defect from those timings. No live AI or agent harness was
used. No energy, allocations, disk syscall counts, or steady-state server memory
were available. Exact commands and evidence are in the reproduction package.

## Kujo Eval report

The actual Eval scoring unit is pass/fail per deterministic check. No synthetic
0–10 score was introduced.

| Category/check group | Baseline | Current | Delta |
|---|---:|---:|---:|
| Overall actual Eval | 4/11 | 11/11 | +7 |
| Minimal + typical correctness | 3/3 | 3/3 | 0 |
| Filesystem/evidence boundaries | 0/3 | 3/3 | +3 |
| Failure/resource behavior | 1/3 | 3/3 | +2 |
| Agent JSON/tool usability | 0/2 | 2/2 | +2 |

These reporting groups partition the 11 checks; Eval itself records each check
as pass/fail and also preserves its original tags. Definitions and criteria are in
`eval.json` and `EVAL_CRITERIA.md`; raw reports are preserved under `results`.

## Final question

> If we erase the commit messages and ignore what the hardening work intended
> to accomplish, does the empirical evidence independently demonstrate that
> CURRENT is a better engineered version than BASELINE?

**PARTIALLY.** Independent behavior proves that current is far better on large
malformed input, passes all tested trust-boundary contracts, is compatible with
the released runtime, and is more deterministic across repeated tests. It also
proves that current is slower on normal generation and validation, slightly
heavier in memory, larger in code/artifacts, and larger in prompt/context bytes.
The evidence supports “better engineered for reliability and bounded failure,”
not “better on every engineering axis” and not “faster and leaner overall.”
