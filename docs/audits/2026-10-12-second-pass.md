# PackWrite second audit pass — October 12, 2026

Repository: `kujolang/packwrite`, branch `main`.
Starting SHA: `e3f42e79c7d8f8c3a88b6355d3382c32ba9923b4` (clean).
Ending implementation SHA: `bdd6094632a3187705cacb7cc795d9d9efc711b8`.
The following documentation commit records this receipt.

## Review and baseline

Revisited the first pass's read wrappers, fake-provider dispatch, generated-prompt
emission, manifest validation/planning, output-location checks, staging/promotion,
and their unit/CLI coverage. Baseline `make test` passed all 209 unit and 67 CLI
assertions using local Kujo 1.5.0. No live provider or credentials were used.

| Missed problem | Baseline reproduction | Fix and regression coverage |
| --- | --- | --- |
| An explicit missing offline response file fell through to inline content or provider execution | Missing `PACKWRITE_FAKE_RESPONSE_FILE` with an intentionally unsupported provider returned a provider-resolution error instead of a fixture error | Resolve fixtures through `read_text` and return an error envelope; never fall through. CLI cases cover missing, directory, invalid UTF-8, and precedence over inline content. `ai_generate` rejects an explicitly non-string fake before provider resolution. |
| A manifest could declare both a file and a child of that file | `agent/extra` plus `agent/extra/child.md` returned dry-run exit 0, then write exit 4 from directory creation and left a stage behind | Check all manifest ancestors against the complete path set before staging. Unit tests cover both entry orders, dry-run and real writes, and no filesystem artifacts. |
| A nested output path could have an existing file as its parent | Output-location validation checked symlinks but not non-directory ancestor components, leaving the failure to directory creation | Reject existing non-directory ancestors before model execution or staging; test that the original file is preserved. |
| Saved prompt reads still bypassed the guarded reader | Invalid UTF-8 in `agent/DEEPSEEK_START.md` caused uncaught runtime exit 4 | Use the read envelope and operational exit 1; reject live/dangling symlinks and directory prompts. CLI tests cover invalid UTF-8, directory, dangling link, and preserved missing-file fallback. |

## Compatibility

Public command names, help text, argument shapes, success output, generated pack
format, configuration keys, and environment variables are unchanged. Existing
regular prompt files still print verbatim; genuinely missing prompts still use the
built-in fallback. Explicit fake response files retain precedence over inline
responses; invalid files now fail instead of selecting another input or provider.

Invalid manifests and unreadable saved prompts now return operational errors
instead of dry-run success, runtime crashes, or misleading defaults. Generated
prompt symlinks are intentionally refused, consistent with existing pack validation.
Output ancestor files are rejected early. No supported public function signature was
removed; the existing symlink predicate is exported for reuse within the command
module. No package dependency, runtime minimum, or downstream integration change.

## Verification

- `make test`: **218 unit + 74 CLI assertions passed** (16 added regressions).
- `make check` and Bash syntax gate: passed as part of the full suite.
- `make smoke`: version/help passed.
- `git diff --check`: passed.
- Existing offline generation, overwrite/prune, nested output, golden validation,
  raw-response handling, JSON/quiet modes, and exact help remain covered.
- Fake failure tests use an unsupported provider and explicit fixture errors as the
  oracle: no real model request is necessary or permitted by the test design.

No speed, token, or memory improvement is claimed. These changes strengthen failure
semantics and prevent unintended work. Previously documented concurrent hostile
filesystem mutation limits remain; this pass does not claim race-free transactions.
No newly established unresolved blocker or mandatory sibling-repository change.
