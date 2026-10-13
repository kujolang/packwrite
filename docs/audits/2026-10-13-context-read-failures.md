# PackWrite hardening sweep — repository context read failures

Repository: `kujolang/packwrite`. Date: 2026-10-13. Starting branch: `main`.
Starting SHA: `f6950a85237c1cd5f657841bec2cbb34e9e525d7`.
Ending implementation SHA: `5b289ade5a0b7fa62769c6104866597675abe530`;
a following documentation commit contains this report.

This sweep revisited input/context collection, its CLI handoff, filesystem failure
boundaries, existing validation protections, and the offline regression suite.
PackWrite's Kujo runtime, filesystem utilities, and OpenAI-compatible provider seam
remain unchanged. No new dependencies, live provider requests, or sibling writes.

| Reproduced failure | Root cause / fix | Compatibility / proof |
| --- | --- | --- |
| A mode-000 included `src` directory, or a repository root with search permission but no read permission, crashed `init --dry-run` with exit 4 and VM stderr. Quiet mode also crashed. | Context enumeration called `list_dir` without a guard. Catch only enumeration failures, propagate a directory-specific error through private helpers, and stop `init` with exit 1 before building/sending a provider request. | Four CLI cases cover both directory locations and normal/quiet modes. Two cases restore permissions and verify dry-run success; one verifies an explicitly excluded unreadable subtree still permits generation planning. No output pack is written on failure. |

`context_collect` retains its exact successful `{summary,warnings}` shape and now
returns `{error}` on enumeration failure, where it previously threw. Its signature
is unchanged. Private subtree collection uses an envelope to propagate errors.
No readable context, sorting, caps, inclusion/exclusion policies, rendered prompts,
CLI success output, config, environment variable, generated file format, or JSON
schema changed. Direct callers can handle the new error return instead of a runtime
exception. No existing successful consumer requires migration.

## Verification

- Baseline `make test`: 248 unit + 101 CLI assertions passed.
- Final `make test`: 248 unit + 108 CLI assertions passed; no permission cases skipped.
- Independent Python subprocess probes used temporary repositories, mode `000` for
  `src` and `100` for the root, restoring `700` in `finally`. Before: exit 4 and VM
  stderr. After: all four normal/quiet cases return exit 1, an actionable stdout error,
  empty stderr, and no provider-request progress marker.
- `make smoke`, `bash .github/scripts/check-kujo-tool-artifacts.sh`, and
  `git diff --check`: passed.
- Logs and before/after receipts: `/tmp/packwrite-context-sweep/` (temporary).
- Seven new permission assertions explicitly skip under root; together with the
  previous nine, 16 tests require an ordinary user. Local and hosted run counts
  confirm whether all execute.
- Hosted Kujo 1.2.2 CI and artifact guard must pass on the exact candidate before
  main advances. Final SHA/run IDs are recorded in the Strata handoff.

No measured performance or token gain is claimed: this corrects failure handling,
without changing generation or resource limits. It does not add a concurrency
contract. Existing filesystem-race limitations remain as documented in prior
reports. No new unresolved blocker or cross-repository requirement was established.
