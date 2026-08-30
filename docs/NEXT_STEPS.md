# PackWrite — Next Steps

Review date: August 30, 2026

The single, current, prioritized backlog for PackWrite, refreshed after the repository
hardening pass. Treat this file as the source of truth.

Each remaining item names the module(s) it touches so it can be picked up cold. Any
future implementation still requires normal compatibility and regression review.

## Completed hardening

- Validated numeric CLI flags up front (`--temperature` 0.0–2.0, `--timeout` positive):
  malformed input now returns a clear error instead of crashing the runtime.
- Hardened the manifest path sandbox further (backslash separators and `~` home-
  expansion prefixes rejected, on top of the segment-aware traversal/ambiguous-segment
  and secret-path checks added on June 19).
- Added `packwrite doctor --strict` so CI can gate on resolvable endpoint, API key, and
  mega prompt presence; plain `doctor` stays informational (exit 0).
- Updated README/AGENTS/CHANGELOG and the configuration/troubleshooting docs to match.
- Fixed staged promotion and rollback for nested output directories.
- Added strict post-layer config type/range validation and endpoint sanity checks.
- Added model-response/file/path resource limits and bounded invalid-response diagnostics.
- Rejected output symlink ancestors and control-bearing model/context paths.
- Made raw-response saves atomic, owner-only, symlink-safe, and no-overwrite.
- Added shell-syntax, nested-output, symlink, resource, config, endpoint, context, and
  raw-response regression coverage.

## High value

1. **Read-only `summary` command (`src/cli.kujo`, `src/validate.kujo`).**
   Implement the deferred `packwrite summary` using existing validation helpers: print
   pack status, phase count, missing files, warnings, and the next suggested command
   without calling AI. Highest-leverage next feature.

2. **Machine-readable output: `validate --json` and `doctor --json` (`src/cli.kujo`).**
   Emit the validation envelope (`ok`, `errors`, `warnings`) and doctor blockers as a
   single JSON object for CI and downstream agents. Keep the human format as default;
   `--json` switches. Pairs naturally with `doctor --strict`.

3. **Network resilience for `ai_generate` (`src/ai.kujo`).**
   The model call is single-shot. Add a bounded retry (e.g. 2 retries, linear backoff)
   for transient transport failures, gated so the fake-injection seam and offline suite
   are untouched. Distinguish retryable (timeout/5xx/connection) from non-retryable
   (auth/4xx); surface attempt count under `--verbose`.

4. **Policy file support (`src/config.kujo`, `src/pack.kujo`).**
   Add an optional `[policy]` section for org defaults: allowed output dirs, allowed
   providers, required minimum phase count, and whether raw-response saves are disabled.
   Makes PackWrite easy to standardize across teams.

5. **Golden `/agent` fixture (`tests/fixtures/`).**
   Commit a small golden pack and validate it directly, so the expected pack shape is
   inspectable rather than only generated at test time.

## Medium value

6. **Pack comparison workflow (`compare`).**
   Offline-first command that diffs two existing pack dirs or two generated runs.
   Deterministic diffs + validation scores first; model-assisted judging later.

7. **Repair workflow (`repair-pack`).**
   After `summary`/`compare` exist: consume `validate_run` errors, ask the model only
   for a corrected manifest, then reuse `pack_apply` + validation with the same path and
   secret guardrails.

9. **Configurable secret/redaction patterns (`src/repo_context.kujo`, `src/pack.kujo`).**
   Allow `[repo_context].secret_names` / `secret_exts` (additive to the built-ins) so
   teams with house conventions (`*.token`, `vault/`) get the same guarantees.

10. **Provider compatibility matrix (docs).**
    A table of tested endpoint shapes for DeepSeek, OpenAI, local OpenAI-compatible
    servers, OpenRouter, and LiteLLM, with exact notes for providers that need a gateway.

## Lower value / polish

11. **`--quiet` flag (`src/cli.kujo`).** Suppress `[n/8]` progress lines and the summary,
    printing only errors — friendlier for scripting alongside `--json`.

13. **Validation severity config (`src/validate.kujo`).** Let `[pack]` promote selected
    warnings to errors (e.g. `strict_review_checklist`) for a harder CI quality bar.

14. **Stage-dir cleanup safety net (`src/pack.kujo`).** Sweep orphaned
    `.<out>.packwrite-stage-*` / `-backup-*` dirs left by a crashed run, with a
    `--verbose` note.

15. **Performance: memoize repeated reads in `validate_run` (`src/validate.kujo`).**
    Phase files and structured docs are read more than once across the section, phase,
    and scan passes; a single read-into-dict pass would cut I/O on large packs. Low
    urgency — current packs are small.

16. **Docs examples audit + installation polish.** Re-run every README/HOWTO/config/
    troubleshooting command in a temp dir before the next release tag; add a release
    checklist (interpreter assumptions, PATH, shell completion, post-install smoke test).

## Suggested next-session order

1. Implement `packwrite summary` (item 1).
2. Add `validate --json` / `doctor --json` (item 2).
3. Create the golden pack fixture (item 5).
4. Update docs and integration tests around those new read-only surfaces.

## Notes for whoever picks this up

- Run `make test KUJO=kujo` before and after — keep the
  suite green (currently 168 unit + 58 CLI integration assertions, fully offline).
- Preserve exact CLI help text: `tests/cli_integration.sh` treats it as a contract.
- Honor the Kujo runtime gotchas in `AGENTS.md`/`CONTRIBUTING.md` (one `for` per scope,
  `write_text` delete-then-write, uniquely-named helper locals, char-safe string
  helpers, guarded `parse_json`/`parse_toml`).
- Keep the rule that only `src/cli.kujo` prints and chooses exit codes; everything else
  returns `{"ok":…}` envelopes.
