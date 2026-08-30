# Architecture

PackWrite is a small, deterministic CLI with one well-isolated AI call. The design goal
is that the *shape* of the output (files, sections, validation) is owned by code, and
the model only fills in *content*.

## Principles

1. **Local-first.** Runs from any repo's terminal; the repo-local files are the source
   of truth. The only network call is the AI request.
2. **AI-assisted, not AI-only.** Deterministic Kujo owns structure, parsing, validation,
   config, safety, and next-step guidance. The model generates pack content; PackWrite
   enforces the contract.
3. **Provider-swappable.** Everything depends on a single adapter function,
   `ai_generate(...)`, never on a specific provider API.
4. **Guardrail-heavy & safe by default.** Secrets and dependency trees are excluded from
   context; writes are sandboxed to the output directory; nothing destructive runs.
5. **Honest surface.** Config keys either do something or are documented as reserved;
   deferred commands say so instead of pretending.

## Module map

| Module | Responsibility | Key exports |
| --- | --- | --- |
| `packwrite.kujo` | Entrypoint; turns `args()` into a process exit code. | — |
| `src/cli.kujo` | Arg parsing + command dispatch. **The only module that prints** and chooses exit codes. | `main`, `dispatch` |
| `src/config.kujo` | Layered config resolution and TOML loading. | `config_load`, `config_resolve`, `config_defaults` |
| `src/prompt.kujo` | Mega-prompt discovery and reading. | `prompt_resolve`, `prompt_read` |
| `src/repo_context.kujo` | Lightweight, redacted repo summary (include/exclude, secret skip). | `context_collect`, `context_render` |
| `src/ai.kujo` | The model boundary: adapter over `ai_chat`, endpoint/key resolution, distillation-prompt builder. | `ai_generate`, `ai_distillation_prompt`, `resolve_endpoint` |
| `src/pack.kujo` | Manifest/resource limits, config/path/symlink safety, overwrite/prune, staged write/dry-run. | `pack_parse`, `pack_apply`, `pack_guard_overwrite`, `pack_validate_config`, `safe_target` |
| `src/validate.kujo` | Deterministic pack validation and read-only summaries (no AI). | `validate_run`, `summary_run`, `required_files` |
| `src/util.kujo` | Predicates, char-safe string helpers, safe fs read/write. | `truthy`, `str_find`, `write_text`, … |
| `src/errors.kujo` | Result envelopes and canonical user-facing messages. | `ok`, `err`, `is_ok`, `msg_*` |

## Data flow: `packwrite init`

```text
argv
  │  cli.parse_args
  ▼
config_load ──────────────► resolved config  (defaults < global < toml < flags)
  │
  ▼
prompt_resolve / prompt_read ► mega prompt text
  │
  ▼
pack_guard_overwrite ───────► abort if agent/ exists and --overwrite not set
  │                            and reject unsafe output-dir config
  │
  ▼
context_collect / render ───► redacted repo summary (names only; secrets skipped)
  │
  ▼
ai_distillation_prompt ─────► the instruction + mega prompt + context
  │
  ▼
ai_generate ────────────────► model response text   (adapter; fake-able in tests)
  │
  ▼
pack_parse ─────────────────► { files: [{path, content}] }   (tolerant JSON)
  │
  ▼
pack_apply ─────────────────► validate paths → prune orphans → write files
  │
  ▼
validate_run ───────────────► { ok, errors[], warnings[] }
  │
  ▼
cli.print_summary ──────────► summary + next command, exit code
```

`validate`, `summary`, and `prompt` reuse the same config and pack layers without the AI call.

## The AI adapter boundary

`src/ai.kujo` is the only place that touches the model. The rest of PackWrite calls:

```text
ai_generate(prompt, cfg, opts) -> { "ok": bool, "text": str, ... }
```

- In production, `ai_generate` calls the in-house `ai_chat` builtin, matching on its
  `Result` (`Ok({message,...})` / `Err(string)`), and resolves the endpoint from a
  provider preset or explicit `--endpoint`. The adapter speaks the OpenAI-compatible
  chat protocol only.
- In tests, callers pass `opts["fake"]` (or set `PACKWRITE_FAKE_RESPONSE[_FILE]`), and
  `ai_generate` returns that string verbatim — no network, no key.

This single seam is what makes PackWrite both provider-swappable and fully testable
offline.

## Result-envelope convention

Library functions never print and never `exit`. They return
`{"ok": true, ...}` or `{"ok": false, "error": "..."}`. `src/cli.kujo` is the only
layer that interprets envelopes into stdout messages and exit codes:

- `0` success
- `1` operational failure (missing prompt, AI failure, validation failure)
- `2` usage error (bad/missing arguments, unknown/deferred command)

## Extension points

The module seams are designed so the deferred features slot in without restructuring:

- **`compare`** — call the existing `init` pipeline N times into separate `--output`
  dirs (the `run_name`/`--run-name` field is already reserved for labeling runs), then
  add a scoring module that consumes `validate_run` results.
- **`repair-pack`** — feed a `validate_run` failure report plus the pack back through
  `ai_generate` with a repair-oriented prompt, then re-`pack_apply` + `validate_run`.
- **New providers** — extend `endpoint_presets()` in `ai.kujo`; everything else is
  unchanged because callers only see `ai_generate`.

## Runtime notes

PackWrite targets the Kujo interpreter. A few runtime quirks shape the code (one `for`
per scope, byte-vs-char string indexing, delete-then-write file semantics, recursion +
helper clobbering in hot loops). These are documented in
[CONTRIBUTING.md](../CONTRIBUTING.md#kujo-runtime-gotchas-please-internalize-these);
new code must follow the same patterns.
