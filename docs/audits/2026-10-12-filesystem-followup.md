# PackWrite renewed hardening audit — 2026-10-12

## Scope and baseline

Repository: `kujolang/packwrite`; starting branch: `main`; starting SHA:
`a9a8602d8e133f824ec89fd8049b6ffdcf4001a0`. Ending implementation SHA:
`235ba02eb1b6add7ae0b3a080e307a4bdaa2b9a7`; the following documentation commit
contains this report.

PackWrite compiles a mega prompt into a validated execution pack. This follow-up
extends [the full October audit](2026-10-12-hardening.md) and subsequent compatibility
reviews, preserving their immutable measurements. Revisited the source modules,
configuration, CLI/provider boundary, parser and path checks, stage/promotion/cleanup
flow, test harness, build/CI gates, examples and release guidance. The dependency
surface remains Kujo builtins, Bash/Make and existing filesystem utilities; there
are no package dependencies. Relay/Tribunal integration contracts remain unchanged.
No live provider request, release, or sibling-repository modification was performed.

Fresh baseline: all static and shell checks and 232 unit assertions passed; 77/78
CLI assertions passed. The failing prompt test used `grep -q` under `pipefail`,
closing stdout before Kujo finished printing and triggering a broken-pipe panic.
This was a baseline failure, not a regression from these changes.

## Evidence-backed changes

| Problem / root cause | Change and regression proof | Compatibility / measured impact |
| --- | --- | --- |
| `ensure_dir` exceptions escaped `pack_apply`, leaving partially written stages | A private directory-preparation guard converts only directory creation failures into the existing error envelope. Each stage failure cleans its owned stage. Five unit assertions exercise failure, old-pack preservation, cleanup and retry; CLI probes cover output-parent, staging-root and nested-directory failures. | Previously exit 4 with VM traceback and one leftover stage; now exit 1, actionable stdout error, no stderr and no leftover stage. Valid paths remain valid; no portable filename limit is imposed. |
| Prompt test readers closed the pipe early | Capture complete command output before matching the expected substring in three CLI checks. Existing content and exit-status assertions remain effective. | Test-only correction; no product output change or ignored exit code. |
| Example incorrectly equated omitted and empty include lists | Correct `packwrite.example.toml` to distinguish default allow-list from `include = []`. | Aligns copyable guidance with existing resolver behavior; no configuration change. |

Implementation: `src/pack.kujo`; regressions: `tests/packwrite_test.kujo`;
harness fix: `tests/cli_integration.sh`. Counts and changelog were updated.

## Measurements and compatibility

[Machine-readable evidence](evidence/2026-10-12-filesystem.json) includes the
reproducer outcome, all three fixed failure probes and three ordinary generation
samples per checkout under shared host load. Median offline init time was 1.7742 s
before and 1.9684 s after; these samples do not establish a speed improvement or a
stable slowdown. This is a reliability fix, not a performance optimization.

All 13 generated files were byte-identical. Successful quiet output stayed at zero
bytes, and validation JSON remained `{"errors":[],"ok":true,"warnings":[]}`.
Prompt/context construction and budgets were untouched; prior payload measurements
remain applicable. No memory or binary-size claim is made for this interpreted
source change. No dependency, cache, retry layer or new process was introduced.

Public function signatures, generated pack/manifest formats, JSON schemas,
configuration keys/defaults and environment variables are unchanged. Directory
creation errors now use the documented operational-error contract. The private
guard preserves the exported `ensure_dir` interface for external consumers.

## Verification and remaining boundaries

- `make test`: 237 unit + 78 CLI assertions, Kujo checks and Bash syntax checks.
- `make smoke`, `bash .github/scripts/check-kujo-tool-artifacts.sh`,
  `git diff --check`: passed.
- Standalone Python CLI probes generated offline fixtures using
  `kujo run tests/fixture.kujo`, then exercised 256-character directory components
  and a 240-character output basename whose staging suffix exceeds the filesystem
  component limit. All three return operational errors with no staging leftovers.
- Ordinary comparison: three `bin/packwrite init MEGA_PROMPT.md --quiet --overwrite`
  and `bin/packwrite validate --json` runs against each checkout; artifact bytes match.
- Hosted CI on pinned Kujo 1.2.2 and artifact guard must pass on the candidate SHA
  before main advances; exact run IDs and ending state are preserved in Strata.

Trust boundaries reviewed include filesystem errors and ownership of cleanup,
model manifests, config/env input, paths/symlinks, provider errors and subprocess
argv. No new unresolved P0/P1 issue was established. Existing hostile-writer races
and the absence of multi-writer transactions remain the previously documented
boundary; this guard does not claim to eliminate them. No cross-repository change
is required. Speculative parser rewrites, caching and retry changes remain not
worth changing without new evidence.
