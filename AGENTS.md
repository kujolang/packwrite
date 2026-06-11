# AGENTS.md — PackWrite

PackWrite is a standalone Kujo CLI that compiles a `MEGA_PROMPT.md` into a validated
`/agent` execution pack. It is separate from the Kujo language repo (reference-only).

## Layout

```
packwrite.kujo        entrypoint (parses argv -> src/cli main -> exit code)
bin/packwrite         bash wrapper (set KUJO=/path/to/kujo for the interpreter)
src/
  util.kujo           predicates, string/list helpers, safe fs read/write
  errors.kujo         {"ok":bool,...} envelopes + canonical messages
  config.kujo         resolution: defaults < global < packwrite.toml < flags
  prompt.kujo         mega-prompt discovery + reading
  repo_context.kujo   safety-filtered, lightweight repo summary
  ai.kujo             ai_chat adapter (swappable, fake-able) + distillation prompt
  pack.kujo           manifest parse, path safety, overwrite guard, clean-replace write/dry-run
  validate.kujo       deterministic pack validation (no AI)
  cli.kujo            arg parsing + command dispatch (only layer that prints)
tests/
  run.sh              unit harness + CLI integration
  packwrite_test.kujo offline unit assertions
  fixture.kujo        emits a valid fake manifest
  cli_integration.sh  drives the real binary via PACKWRITE_FAKE_RESPONSE_FILE
```

## Conventions / gotchas (Kujo runtime)

- One `for` loop per function scope passes `kujo check`; everything here uses `while`.
- `write_file` overwrite flag is broken — `util.write_text` deletes then writes.
- No `import ... as`; every module exports uniquely-named functions.
- Helper locals are uniquely named (e.g. `ls_i`/`ls_n`) so they can't clobber a caller.
  Tree walks are iterative with an explicit stack (recursion + a helper in one hot loop
  corrupts the loop index — see `pack.kujo` `collect_files`).
- `len`/`index_of` are byte-based but `substring` is char-based — never mix them; use the
  char-safe helpers in `util.kujo` (`str_find`, `str_find_from`, `str_rfind`).
- `parse_json` / `parse_toml` are guarded (try/except + type checks); never trusted raw.
- Modules return envelopes; only `cli.kujo` prints and chooses exit codes (0/1/2).
- No stderr stream exists in this runtime: everything prints to stdout, prefixed
  (`warning`/`!`/`note:`/`error:`) so categories stay distinguishable.
- The `ai_chat` adapter is OpenAI-compatible only (`{model, messages}`, Bearer auth,
  `choices[0].message.content`). Presets exist for deepseek/openai/local; native-only
  providers (anthropic, …) require an explicit OpenAI-compatible `--endpoint`.

## Tests

```bash
make test KUJO=/path/to/kujo/target/release/kujo   # or: KUJO=... ./tests/run.sh
```

Fully offline (105 unit + 31 CLI integration assertions). AI calls go through the
fake-injection seam — no API key or network.

## Deeper docs

`docs/ARCHITECTURE.md` (module map + data flow + extension points),
`docs/CONFIGURATION.md` (every key), `docs/HOWTO.md`, `docs/TROUBLESHOOTING.md`, and
`CONTRIBUTING.md` (full runtime-gotcha list).
