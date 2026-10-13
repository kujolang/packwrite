# PackWrite independent compatibility pass — directory read failures

Repository: `kujolang/packwrite`. Date: 2026-10-13. Starting branch: `main`.
Starting SHA: `58d16d3a11397fc7f1c6e7726a2282f28f707ef0`.
Ending implementation SHA: `5dedbd8ebc6efba6817f773d701c08bdb4558e30`
(followed by the documentation commit).

This pass reviewed validation and summary contracts, phase enumeration, recursive
pack inspection, CLI error serialization, and the existing audit regression suite.
PackWrite remains a Kujo CLI with an offline fake-provider test seam and no package
dependencies. No live provider request or sibling repository change was required.

| Reproduced issue | Root cause and correction | Regression proof / compatibility |
| --- | --- | --- |
| A pack root, `phases`, or auxiliary directory with mode `000` caused both `validate --json` and `summary --json` to exit 4, emit a VM error on stderr and emit no JSON. | Three unguarded `list_dir` calls bypassed error envelopes. A private helper catches directory enumeration failures; phase validation and recursive scanning add an actionable error. Phase counting preserves its integer return type and returns 0 when enumeration fails. | Six CLI cases now return exit 1, `ok:false` in valid JSON, an error naming the unreadable directory, and empty stderr. Three additional assertions restore permissions and verify successful validation. Existing readable-pack assertions retain output and phase-count coverage. |

The helper catches only directory enumeration. It does not catch arbitrary
validation failures or convert an unreadable tree into successful validation.
The scan records an error for each unreadable subtree and continues checking other
entries. Summary retains its existing keys, including an error list alongside the
zero phase count when phases cannot be read. Public signatures, successful CLI
output, file formats, config, environment variables, and schemas are unchanged.
Troubleshooting guidance documents the new operational error.

## Verification

- Baseline `make test`: 248 unit + 92 CLI assertions passed, with Kujo and Bash checks.
- Final `make test`: 248 unit + 101 CLI assertions passed; no permission cases skipped.
- Independent Python subprocess probe: copied `tests/fixtures/golden-agent` into
  temporary directories, applied `chmod(0)` to each of the three directory kinds,
  ran `bin/packwrite validate --json` and `summary --json`, parsed JSON after the fix,
  and restored permissions in `finally`. All six before/after results reproduced.
- `make smoke`, `bash .github/scripts/check-kujo-tool-artifacts.sh`, and
  `git diff --check`: passed.
- Evidence logs: `/tmp/packwrite-independent-next/{baseline.log,after.log,before.json,after.json}`.
  Temporary files may expire; the observed outcomes are preserved in this report.
- Permission assertions explicitly skip under root because root bypasses Unix mode
  bits. Local and hosted verification must run as ordinary users to exercise all nine.
- Hosted CI on pinned Kujo 1.2.2 and the artifact guard must pass on the candidate
  before main advances. Final SHA and exact run IDs are preserved in Strata.

No performance gain is claimed. Directory enumeration count, provider context,
resource limits and dependencies are unchanged. This corrects a failure contract;
it does not add a concurrency guarantee. Existing filesystem-race limitations
remain as previously documented. No new unresolved blocker, cross-repository
requirement, or consumer migration was established by this pass.
