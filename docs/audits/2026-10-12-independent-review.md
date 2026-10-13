# PackWrite independent audit-change review — 2026-10-12

Reviewed all audit changes from `3f0cbf4b5052677d22040cdf486adf2817b40a20`
through `55dc662240932c6aa7d6aba848671689e2b3a55b` on `main`, including
source, regression tests, benchmark evidence, build gates, and documentation.
Prior audit reports retain their original measurements and scope.

## Reproduced compatibility regression

The added context omission counters became required inputs to the exported
`context_render` API. A previously valid summary with no `omitted` field, including
an ordinary subtree, rendered successfully at the original baseline but exited 4
with `Missing map key: "omitted"` after the audits.

Both rendering sites now check for the additive field before reading it. Three
regression assertions cover legacy top-level summaries, legacy subtrees, and the
absence of invented omission notices. Existing tests retain exact counts and
notices for bounded context collected by the current implementation.

No CLI, configuration, environment, output-pack, or provider contracts change.
The collector still emits omission metadata and enforces all existing bounds and
filters. External callers can continue rendering older context envelopes. No
other repository needs modification. No additional reproducible issue was found.

## Verification

- Baseline `make test`: 229 unit + 78 CLI assertions passed.
- Final `make test`: 232 unit + 78 CLI assertions passed, including Kujo checks
  and shell syntax validation.
- `make smoke`, `bash .github/scripts/check-kujo-tool-artifacts.sh`, and
  `git diff --check`: passed.
- Local runtime: Kujo 1.5.0. Hosted CI validates pinned Kujo 1.2.2 before main
  advances; exact run IDs and final commit are retained in the Strata handoff.
- The standalone legacy-envelope reproducer succeeds after the fix.

No performance claim is made for these optional-field guards. There are no new
unresolved findings from this review.
