# Contributing

Thanks for helping improve this Kujo ecosystem project.

This guide is intended for standalone Kujo tools and primitives. It does not
cover the core Kujo language repo, Kujo Skills, or Kujo Workflows when those
projects have their own contribution rules.

## Development Principles

- Keep changes focused, reviewable, and tied to one user-visible concern.
- Prefer deterministic, local-first behavior.
- Do not add network calls, provider calls, timestamps, or machine-specific
  output to core command paths unless the feature explicitly requires it.
- Preserve redaction, path safety, guarded cleanup, and stable output ordering.
- Add tests for behavior changes. Bug fixes should include regression coverage.
- Avoid speculative refactors unless they directly simplify the change at hand.

For PackWrite specifically:

- Keep structure, parsing, validation, config, and safety deterministic.
- Keep AI/provider behavior behind fake-able adapter boundaries.
- Preserve exact CLI output, prompt text, exit codes, JSON/config shapes,
  validation rules, and copyable examples unless intentionally changing the
  contract and updating tests.

## Local Setup

Install Kujo so the `kujo` command is available on your `PATH`:

```bash
kujo --version
```

PackWrite is written in Kujo and run by the Kujo interpreter.

Project layout:

```text
packwrite.kujo          entrypoint: parse argv -> src/cli main -> exit code
bin/packwrite           bash launcher that uses `kujo` by default and preserves cwd
src/
  util.kujo             predicates, char-safe string helpers, safe fs read/write
  errors.kujo           result envelopes and canonical user messages
  config.kujo           resolution: defaults < global < packwrite.toml < flags
  prompt.kujo           mega-prompt discovery and reading
  repo_context.kujo     lightweight, redacted repo summary
  ai.kujo               AI adapter, fake seam, and distillation prompt
  pack.kujo             manifest parse, path safety, overwrite/prune, dry-run
  validate.kujo         deterministic pack validation
  cli.kujo              arg parsing and command dispatch; only layer that prints
tests/
  run.sh                unit harness plus CLI integration
  packwrite_test.kujo   offline unit assertions
  fixture.kujo          valid fake model manifest generator
  cli_integration.sh    real binary integration through the fake-response seam
docs/                   HOWTO, CONFIGURATION, ARCHITECTURE, TROUBLESHOOTING
```

See `docs/ARCHITECTURE.md` for the data flow and design principles.

## Agent And Example Hygiene

Start with `README.md`, `CONTRIBUTING.md`, relevant docs, and examples before
broad source sweeps.

Treat user-facing examples as canonical copyable surfaces. Examples should be
short, runnable, and representative of the idioms humans and agents should copy.

Canonical PackWrite examples live in `README.md`, `docs/HOWTO.md`, and
`packwrite.example.toml`.

Treat `tests/fixture.kujo`, `tests/packwrite_test.kujo`, and
`tests/cli_integration.sh` as behavior contracts. They may be intentionally
explicit or repetitive so failures are easy to diagnose; do not shorten them
just to improve style unless the contract remains clearer afterward.

For readability sweeps, start with:

```bash
rg "pattern" src README.md docs AGENTS.md CONTRIBUTING.md packwrite.example.toml
```

Exclude generated and bulk paths from broad searches unless the task explicitly
targets them. Skip `agent/`, `.git/`, `target/`, `dist/`, `build/`, `coverage/`,
`node_modules/`, and `.venv/` by default.

Document any important search exclusions in larger cleanup or audit PRs.

## Code Standards

- Match the surrounding code style before introducing a new abstraction.
- Keep command output readable and stable.
- Prefer small local helpers for repeated output, error, section, or key/value
  formatting once repetition distracts from the behavior.
- Keep CLI contracts explicit: flags, exit codes, JSON fields, artifact paths,
  and documented examples should agree with parser behavior.
- Keep config honest. A config key should either change observable behavior or
  be clearly documented as reserved.
- Preserve compatibility entrypoints and wrappers when a repo provides them.
- Only `src/cli.kujo` prints to the user and chooses exit codes. Library modules
  return result envelopes.
- Use `print_lines`, `print_list`, `print_paths`, `print_kv`, `print_usage`,
  and `print_error` in `src/cli.kujo` when output repeats.
- Exit codes are `0` for success, `1` for operational failure, and `2` for
  usage error.
- Depend on `ai_generate(...)`, not the raw `ai_chat` builtin directly.

## Kujo Runtime Notes

Kujo ecosystem tools often follow these defensive patterns:

- Prefer `while` loops in complex functions.
- Avoid duplicate local names across branches in the same function.
- Keep imports at the top of the file.
- Export functions that are imported by another module.
- Guard dictionary access with `has_key()` or local helper wrappers.
- Remember that some builtins return int-like `1`/`0` instead of booleans.
- Guard parsing operations such as JSON or TOML parsing and validate the result.
- Keep deep tree walks iterative where recursion risks VM stack limits.
- Be careful with byte-based string indexes versus character-based substring
  operations; use existing repo helpers when available.

PackWrite-specific runtime notes:

- `kujo check` rejects more than one `for` loop per function scope. Use
  index-based `while` loops.
- `write_file` overwrite behavior is unreliable. Use `util.write_text`, which
  deletes then writes.
- `import ... as alias` is unsupported. Export uniquely named functions.
- `len` and `index_of` are byte-based; `substring` is char-based. Do not mix
  them. Use `str_find`, `str_find_from`, and `str_rfind` in `src/util.kujo`.
- Calling several user functions, especially recursion plus helpers, inside one
  hot loop can corrupt loop state. Prefer iterative algorithms with explicit
  stacks and builtin-only loop bodies.
- Guard every `parse_json` and `parse_toml` in `try { } except e { }` and
  type-check the result.

## Validation

Before opening a pull request, run the strongest local validation available for
the repo.

There is no compile step. Lint every module and run the full offline suite:

```bash
make check
make test
```

or directly:

```bash
./tests/run.sh
```

The test suite is fully offline. AI calls go through the fake-response seam
(`PACKWRITE_FAKE_RESPONSE_FILE`, `PACKWRITE_FAKE_RESPONSE`, or the `dispatch()`
argument in unit tests), so no API key or network access is required. Do not add
tests that call a real provider.

## Documentation And Changelog

Update docs when behavior, configuration, command output, flags, schemas,
examples, or security expectations change.

For PackWrite, check:

- `README.md`
- `docs/`
- `packwrite.example.toml`
- command reference or flags docs
- schema or report format docs
- examples
- `CHANGELOG.md`

User-visible behavior changes should include a `CHANGELOG.md` entry under
`Unreleased` when the repo has that section.

## Pull Requests

A good PR includes:

- Problem statement.
- Change summary.
- User-visible impact.
- Test evidence with commands and outcomes.
- Documentation or changelog updates.
- Known risks or follow-up work, if any.

Keep generated artifacts out of commits unless the artifact is the reviewed
output of the change.

Do not implement deferred commands such as `compare`, `repair-pack`, or
`summary` unless that is the explicit purpose of the PR.

## License

By contributing, you agree that your contributions will be licensed under the
MIT License.
