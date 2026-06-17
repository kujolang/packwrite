# Contributing to PackWrite

Thanks for your interest in improving PackWrite. This guide covers the development
setup, the conventions the codebase follows, and the bar a change needs to clear.

## Prerequisites

PackWrite is written in the [Kujo language](#about-kujo) and run by the Kujo
interpreter. You need a `kujo` binary available. Point the tooling at it with the
`KUJO` environment variable:

```bash
export KUJO=/path/to/kujo/target/release/kujo
```

If `kujo` is already on your `PATH`, you can skip that.

## Project layout

```
packwrite.kujo          entrypoint: parse argv -> src/cli main -> exit code
bin/packwrite           bash launcher (honors $KUJO, preserves cwd)
src/
  util.kujo             predicates, char-safe string helpers, safe fs read/write
  errors.kujo           {ok,...} result envelopes + canonical user messages
  config.kujo           resolution: defaults < global < packwrite.toml < flags
  prompt.kujo           mega-prompt discovery + reading
  repo_context.kujo     lightweight, redacted repo summary (include/exclude)
  ai.kujo               ai_chat adapter (swappable, fake-able) + distillation prompt
  pack.kujo             manifest parse, path safety, overwrite/prune, write/dry-run
  validate.kujo         deterministic pack validation (no AI)
  cli.kujo              arg parsing + command dispatch (only layer that prints)
tests/
  run.sh                runs the unit harness + CLI integration
  packwrite_test.kujo   offline unit assertions
  fixture.kujo          emits a valid fake model manifest
  cli_integration.sh    drives the real binary via the fake-response seam
docs/                   HOWTO, CONFIGURATION, ARCHITECTURE, TROUBLESHOOTING
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the data flow and design
principles.

## Examples and search hygiene

Canonical, copyable examples live in `README.md`, `docs/HOWTO.md`, and
`packwrite.example.toml`. Keep those examples minimal, runnable, and representative of
the idioms we want agents to imitate.

`tests/fixture.kujo`, `tests/packwrite_test.kujo`, and `tests/cli_integration.sh` are
contract fixtures. They may be intentionally explicit or repetitive so failures are
easy to diagnose; do not shorten them just to improve style unless the contract remains
clearer afterward.

For readability sweeps, start with:

```bash
rg "pattern" src README.md docs AGENTS.md CONTRIBUTING.md packwrite.example.toml
```

Exclude generated or bulk paths (`agent/`, `.git/`, `target/`, `dist/`, `build/`,
`coverage/`, `node_modules/`, `.venv/`) unless the task explicitly targets them.

## Build & test

There is no compile step. Lint every module and run the full suite:

```bash
make check     # kujo check on every .kujo file
make test      # kujo check + ./tests/run.sh (unit + CLI integration)
```

or directly:

```bash
KUJO=/path/to/kujo ./tests/run.sh
```

The test suite is **fully offline**. AI calls go through a fake-injection seam
(`PACKWRITE_FAKE_RESPONSE_FILE` / `PACKWRITE_FAKE_RESPONSE`, or the `dispatch()`
argument in unit tests), so no API key or network access is required — and tests must
stay that way. Do not add tests that call a real provider.

## Coding conventions

- **Single responsibility per module.** Only `src/cli.kujo` prints to the user and
  chooses exit codes. Library modules return `{"ok": bool, ...}` envelopes (see
  `src/errors.kujo`).
- **CLI output helpers.** Use `print_lines`, `print_list`, `print_paths`, `print_kv`,
  `print_usage`, and `print_error` in `src/cli.kujo` when output repeats. Preserve the
  exact user-facing text unless the change intentionally updates the CLI contract.
- **Exit codes:** `0` success, `1` operational failure, `2` usage error.
- **Deterministic core.** Structure, parsing, validation, config, and safety are pure
  Kujo with no AI involvement. The model only generates pack *content*.
- **Keep it provider-agnostic.** Everything depends on `ai_generate(...)`, never on the
  raw `ai_chat` builtin directly.
- **Honest config.** A config key must either change observable behavior or be clearly
  documented as reserved (in `config.kujo`, `README.md`, and `packwrite.example.toml`).

### Kujo runtime gotchas (please internalize these)

These are real quirks of the Kujo runtime that the code is written to avoid. New code
must follow the same patterns:

- **`kujo check` rejects more than one `for` loop per function scope.** Use index-based
  `while` loops (the codebase uses `while` almost everywhere).
- **`write_file`'s overwrite flag is broken.** Use `util.write_text`, which deletes then
  writes.
- **`import ... as alias` is unsupported.** Every module exports uniquely-named
  functions.
- **Byte vs. char indexing:** `len`/`index_of` are byte-based, `substring` is
  char-based. Never mix them. Use the char-safe helpers in `util.kujo`
  (`str_find`, `str_find_from`, `str_rfind`).
- **Callee-clobbers-caller-locals:** calling several user functions (especially
  recursion + a helper) inside one hot loop can corrupt the loop index. Prefer
  iterative algorithms with an explicit stack and builtin-only loop bodies (see
  `pack.kujo`'s `collect_files`).
- **Guard every `parse_json` / `parse_toml`** in `try { } except e { }` and type-check
  the result; they can throw or return error values on bad input.

## Pull requests

1. Branch from the default branch.
2. Make the change, with tests. Bug fixes should add a regression test; features should
   add unit and (where it touches the CLI) integration coverage.
3. Run `make test` — it must be green, and every `.kujo` file must pass `kujo check`.
4. Update docs if behavior or config changed (`README.md`, `docs/`, `packwrite.example.toml`).
5. Add a `CHANGELOG.md` entry under "Unreleased".
6. Keep PRs focused and scoped. Do not implement the deferred commands (`compare`,
   `repair-pack`, `summary`) unless that is the explicit purpose of the PR.

## About Kujo

PackWrite is a standalone tool in the Kujo ecosystem (alongside RunLedger, Howl, Yard,
and others). It lives in its own repository and depends only on the Kujo interpreter —
it does not modify the Kujo language repo, which is reference-only.

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
