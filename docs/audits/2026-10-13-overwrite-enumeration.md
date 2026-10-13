# PackWrite independent sweep — overwrite enumeration failures

Repository: `kujolang/packwrite`. Date: 2026-10-13. Starting branch: `main`.
Starting SHA: `8567357d597c2e36f20a92cf74fc9dc952e72234`.
Ending implementation SHA: `4eaf7c550e61ee0c2cbf93240db5ad469790240d`;
followed by the documentation commit.

This pass examined the writer's remaining directory-enumeration boundaries,
staging lifetime, orphan accounting, cleanup and promotion ordering, and existing
regression coverage. The Kujo runtime and offline provider seam are unchanged.
No dependencies, live model requests, or sibling repository writes were added.

| Reproduced issue | Root cause / fix | Verification and compatibility |
| --- | --- | --- |
| Overwriting a valid pack containing an unreadable auxiliary directory exited 4 and left `.agent.packwrite-stage-0` behind. | Orphan enumeration threw after staging validation. Private file enumeration and orphan counting now return envelopes; the writer removes its stage and returns the error before promotion. | Normal and quiet CLI checks require exit 1 and no VM stderr. A full directory diff proves the previous pack is preserved and a glob verifies no stage/backup remains. Retry after restoring permissions succeeds. |
| A nested output parent with write/search but no read permission crashed during stale-workdir enumeration. | Cleanup's unguarded `list_dir` escaped the writer. Return an explicit directory-read error before staging. | The same failure/preservation/retry checks cover this parent case. Successful cleanup counts and policy remain unchanged. |

Public function signatures, successful `pack_apply` envelopes, pruning/cleanup
counts, CLI success output, config, environment variables, schemas and generated
file formats remain unchanged. Only private helper return types change. Failed
operations now follow exit 1 and the canonical stdout error contract. Filesystem
state is preserved instead of leaking a stage. No consumer migration is required.

## Verification

- Baseline `make test`: 248 unit + 108 CLI assertions passed.
- Final `make test`: 248 unit + 116 CLI assertions passed; no permission cases skipped.
- Independent reproducer `/tmp/packwrite-overwrite-sweep/probe.py`: copies the golden
  pack, uses a fake manifest, then denies read permission on an existing subtree
  (mode 000) or output parent (mode 300). Permissions are restored in `finally`.
  Both before cases exit 4; the subtree case leaks one stage. After: both exit 1,
  empty stderr, original MASTER bytes retained, zero stages. Receipts are in
  `before.json` and `after.json` beside the probe; temporary evidence may expire.
- Eight new CLI assertions cover both modes, full old-pack preservation, no leaked
  stage/backup, and recovery. These require a non-root user, bringing permission
  assertions to 24; root runs explicitly report skips.
- `make smoke`, `bash .github/scripts/check-kujo-tool-artifacts.sh`, and
  `git diff --check`: passed.
- Hosted CI on Kujo 1.2.2 and artifact guard must pass on the exact candidate before
  main advances. Final SHA/run IDs are preserved in the Strata handoff.

No runtime, memory or token improvement is claimed. Normal enumeration work and
resource limits are unchanged; the measured resource correction is removal of the
single leaked stage on the reproduced failure. Previous multiwriter/hostile
filesystem-race limitations remain; this is not a new concurrency guarantee.
No new unresolved blocker or cross-repository requirement was established.
