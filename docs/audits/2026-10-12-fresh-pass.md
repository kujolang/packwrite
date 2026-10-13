# PackWrite fresh correctness pass — 2026-10-12

Repository: `kujolang/packwrite`; starting branch: `main`; starting SHA:
`839f69b0632a441425756d84d26f9e22e86116fa`. Ending implementation commit:
`52b5f6c131c48388848c7e088c59620e489a4b9c`; the following documentation commit
contains this report.

This fresh pass focused on command preflight and manifest/reporting consistency,
beyond the previous directory-creation fixes. Reviewed configuration resolution,
CLI validation/summary/doctor/prompt dispatch, phase identification, manifest checks,
writer planning and relevant regression coverage. Earlier broad audit evidence and
explicit concurrency boundaries remain in the preceding reports.

Baseline `make test`: 237 unit + 78 CLI assertions passed, with all Kujo and Bash
checks. No baseline suite failure was observed. Separate offline probes reproduced
two previously untested defects.

| Reproduction / root cause | Fix and regression coverage | Compatibility |
| --- | --- | --- |
| `init --output build/phases/agent --dry-run` reported 13 phases for the 13-file fixture containing six actual phases. A substring predicate counted any Markdown path containing `/phases/`, including the output ancestor and auxiliary directories. | Count direct `.md` children of the configured output's `phases` directory, matching on-disk validation. Four assertions cover dry-run counts, write/summary agreement, no-phase manifests and auxiliary-only phases. | Supported nested output paths remain accepted. Phase counts become accurate. Manifests without direct phase files fail before reporting dry-run success. Public signatures and pack contents are unchanged. |
| With a placeholder API key and valid endpoint, `doctor --strict --json` returned `ok:true`, `prompt_status:found`, exit 0 for empty, directory and invalid-UTF-8 prompts that `init` rejects. Presence was checked without reading or validating the prompt. | Reuse the existing `prompt_read` envelope. Seven CLI assertions cover all three invalid forms in strict/informational modes and a valid prompt. | Valid prompts remain `found`; absent prompts retain `missing`. Present but unusable prompts gain `invalid` plus an actionable blocker. Strict mode exits 1; informational mode still exits 0. JSON keys, configuration and environment variables are unchanged. |

Files: `src/pack.kujo`, `src/command.kujo`, both test suites, troubleshooting,
changelog and current assertion totals. No external dependency, provider request,
format migration, release, sibling-repository change or speculative optimization
was introduced. Doctor now reads prompt content to check the same contract as init;
this trades a metadata-only check for actual preflight correctness.

## Verification

- `make test`: 241 unit + 85 CLI assertions, Kujo static checks and Bash syntax.
- `make smoke`, `bash .github/scripts/check-kujo-tool-artifacts.sh`,
  `git diff --check`: passed.
- Offline six-phase fixture under `build/phases/agent`: reported phases 13 before,
  6 after; 13 files in both cases. No AI call was used.
- Eight doctor probes: empty/directory/invalid-UTF-8 each fail strict mode and remain
  informational in plain mode; valid input succeeds in both modes.
- Hosted pinned Kujo 1.2.2 CI and artifact guard must pass for the final candidate
  before main advances; exact SHA/run receipts are saved in the Strata handoff.

No runtime, memory or token improvement is claimed. Prompt construction, context
budgets, dependencies and generated file schemas are unchanged. The tests verify
corrected reporting and error behavior rather than implementation details.

No new unresolved blocker or cross-project requirement was established. The
previously documented hostile concurrent-writer boundary remains unchanged; this
pass makes no additional concurrency guarantee.
