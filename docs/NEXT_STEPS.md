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
- Wired hosted CI to the pinned Kujo v1.1.0 Linux x64 release artifact, with SHA-256
  verification before extraction or execution.
- Added read-only `summary`, machine-readable `validate --json` / `summary --json` /
  `doctor --json`, quiet successful init output, and a committed golden pack fixture.
- Added age-gated cleanup for stale PackWrite stage directories and redundant backups;
  recovery backups are retained whenever the final output directory is absent.
- Added a provider/gateway compatibility matrix with explicit certification limits.
- Added an official-release checklist covering version synchronization, local and
  hosted verification, annotated tags, GitHub publication, and post-release checks.

## High value

3. **Network resilience for `ai_generate` (`src/ai.kujo`).**
   The model call remains single-shot. Add bounded retries only after Kujo's AI adapter
   exposes a stable, sanitized status classification that distinguishes transient
   timeout/connection/5xx failures from non-retryable authentication and other 4xx
   failures. Blind retries can duplicate expensive requests.

4. **Policy file support (`src/config.kujo`, `src/pack.kujo`).**
   Add an optional `[policy]` section for org defaults: allowed output dirs, allowed
   providers, required minimum phase count, and whether raw-response saves are disabled.
   Makes PackWrite easy to standardize across teams.

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

## Lower value / polish

13. **Validation severity config (`src/validate.kujo`).** Let `[pack]` promote selected
    warnings to errors (e.g. `strict_review_checklist`) for a harder CI quality bar.

15. **Performance: memoize repeated reads in `validate_run` (`src/validate.kujo`).**
    Phase files and structured docs are read more than once across the section, phase,
    and scan passes; a single read-into-dict pass would cut I/O on large packs. Low
    urgency — current packs are small.

16. **Docs examples audit + installation polish.** Re-run every README/HOWTO/config/
    troubleshooting command in a temp dir before the next release tag; add a release
    checklist (interpreter assumptions, PATH, shell completion, post-install smoke test).

## Suggested next-session order

1. Add organization policy-file support (item 4).
2. Add configurable secret/redaction patterns (item 9).
3. Add validation severity controls (item 13).
4. Revisit retries only after the Kujo adapter exposes safe error classification.

## Notes for whoever picks this up

- Run `make test KUJO=kujo` before and after — keep the
  suite green (currently 182 unit + 66 CLI integration assertions, fully offline).
- Preserve exact CLI help text: `tests/cli_integration.sh` treats it as a contract.
- Honor the Kujo runtime gotchas in `AGENTS.md`/`CONTRIBUTING.md` (one `for` per scope,
  `write_text` delete-then-write, uniquely-named helper locals, char-safe string
  helpers, guarded `parse_json`/`parse_toml`).
- Keep the rule that only `src/command.kujo` prints and chooses exit codes; everything else
  returns `{"ok":…}` envelopes.
