# Next Session Review

Review date: June 19, 2026

> **Superseded by [docs/NEXT_STEPS.md](NEXT_STEPS.md) (June 20).** This file is kept as a
> dated record; the still-open candidates below were carried forward and deduplicated
> into NEXT_STEPS.md, which is the current source of truth.

This pass found PackWrite to be solid for local-first production use: deterministic
validation, offline tests, staged writes, provider isolation, and honest docs are all
in place. It should not be described as a full enterprise platform yet. The next useful
work is to deepen policy controls, comparison workflows, and distribution polish around
the CLI.

## Completed in this pass

- Added explicit output-directory validation: output paths must be non-empty, relative,
  non-traversing, and unambiguous before model calls or filesystem operations.
- Made manifest path traversal checks segment-aware, so legitimate filenames such as
  `notes..draft.md` are allowed while `../` path segments are rejected.
- Rejected secret-looking generated manifest paths before dry-runs or writes can report
  success.
- Updated the README with readiness/scope language, root-file layout guidance, and the
  current offline test count.
- Updated security and architecture docs to match the tightened path model.
- Confirmed the root layout is intentional: runtime logic belongs in `src/`, while
  `packwrite.kujo`, `bin/packwrite`, `Makefile`, `kujo.toml`, and
  `packwrite.example.toml` remain necessary root-level project surfaces.

## Next enhancement candidates

1. **Policy file support**
   Add an optional `[policy]` config section for organization defaults: allowed output
   dirs, allowed providers, required minimum phase count, and whether raw-response saves
   are disabled. This would make PackWrite easier to standardize across teams.

2. **Read-only `summary` command**
   Implement the deferred `packwrite summary` command using existing validation helpers.
   It should print pack status, phase count, missing files, warnings, and next suggested
   command without calling AI.

3. **Pack comparison workflow**
   Implement `compare` as an offline-first command that compares two existing pack dirs
   or two generated runs. Start with deterministic diffs and validation scores before
   adding any model-assisted judging.

4. **Repair workflow**
   Implement `repair-pack` after `summary` and `compare` exist. It should consume
   `validate_run` errors, ask the model only for a corrected manifest, then reuse
   `pack_apply` and validation. Keep the same path and secret guardrails.

5. **Provider compatibility matrix**
   Add a docs table with tested endpoint shapes for DeepSeek, OpenAI, local OpenAI-
   compatible servers, OpenRouter, and LiteLLM. Include exact notes for providers that
   need a gateway.

6. **Golden output fixture**
   Add a small committed golden `/agent` fixture under `tests/fixtures/` and validate it
   directly. This would make the expected pack shape easier to inspect than the current
   generated fixture alone.

7. **Machine-readable validation output**
   Add `packwrite validate --json` for CI and downstream tools. Preserve the current
   human text output as the default CLI contract.

8. **Installation polish**
   Add a release checklist for binary/interpreter assumptions, PATH setup, shell
   completion possibilities, and a minimal smoke test users can run after installation.

9. **Raw response safety**
   Consider making `--save-raw-response` refuse to overwrite existing files unless a
   future `--force` flag is present. This is not urgent, but it would align debug output
   with the rest of PackWrite's conservative write posture.

10. **Docs examples audit**
    Re-run every README, HOWTO, configuration, and troubleshooting command in a temp
    directory before the next release tag. Keep examples focused on canonical docs, not
    test fixture style.

## Suggested next-session order

1. Implement `packwrite summary`.
2. Add `validate --json`.
3. Create the golden pack fixture.
4. Update docs and integration tests around those new read-only surfaces.

