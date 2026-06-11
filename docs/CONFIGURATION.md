# Configuration reference

PackWrite resolves configuration from four layers. Later layers win:

```text
defaults  <  global config  <  project packwrite.toml  <  CLI flags
```

- **defaults** — built in; the tool works with zero config.
- **global config** — `~/.config/packwrite/config.toml` (skipped if `$HOME` is unset or
  the file is absent).
- **project config** — `packwrite.toml` in the working directory, or the file passed to
  `--config <file>`.
- **CLI flags** — highest precedence.

Inspect the fully resolved result and its sources at any time:

```console
$ packwrite config
Resolved configuration:
  sources: defaults -> project:/abs/packwrite.toml -> flags
{ ... }
```

## `packwrite.toml` keys

Types, defaults, and how each key maps to a CLI flag. **Active** keys change observable
behavior; **reserved** keys are parsed but not yet wired (they belong to deferred
features and currently do nothing).

### `[prompt]`

| Key | Type | Default | Flag | Status | Effect |
| --- | --- | --- | --- | --- | --- |
| `file` | string | `"MEGA_PROMPT.md"` | positional arg to `init` | active | Mega prompt path used when none is passed on the command line. |

### `[output]`

| Key | Type | Default | Flag | Status | Effect |
| --- | --- | --- | --- | --- | --- |
| `dir` | string | `"agent"` | `--output` | active | Directory the pack is written to / validated from. |
| `overwrite` | bool | `false` | `--overwrite` | active | Allow replacing an existing pack dir (clean replace; orphans pruned). |
| `mode` | string | `"autopilot"` | — | **reserved** | Parsed but not wired (future generation-mode toggle). |

### `[model]`

| Key | Type | Default | Flag | Status | Effect |
| --- | --- | --- | --- | --- | --- |
| `provider` | string | `"deepseek"` | `--provider` | active | Selects an endpoint preset and the provider-specific API-key env var. |
| `model` | string | `"deepseek-v4-pro"` | `--model` | active | Model identifier sent to the endpoint. |
| `temperature` | number | `0.1` | `--temperature` | active | Sampling temperature. |
| `timeout` | number | `120` | `--timeout` | active | Request timeout in seconds. |
| `endpoint` | string | `""` | `--endpoint` | active | Explicit OpenAI-compatible chat-completions URL; overrides the provider preset. |

### `[repo_context]`

| Key | Type | Default | Flag | Status | Effect |
| --- | --- | --- | --- | --- | --- |
| `include` | string[] | see below | — | active | Top-level allow-list. When non-empty, only these top-level names are shown to the model (included directories are summarized one level deep). Empty/omitted = include everything not excluded. |
| `exclude` | string[] | see below | — | active | Names always skipped (in addition to secret-looking paths). |

Default `include`:
```toml
["README.md", "package.json", "pyproject.toml", "Cargo.toml", "go.mod", "kujo.toml", "src", "tests", "docs"]
```

Default `exclude`:
```toml
[".env", ".env.local", ".git", "node_modules", "vendor", "dist", "build", ".next", "coverage", "target", ".venv"]
```

Regardless of these lists, PackWrite **always** skips secret-looking paths (`.env*`,
`*.pem`, `*.key`, `id_rsa`, `id_ed25519`, names containing `secret`/`token`, etc.) and
never sends file contents beyond a single README summary line. See [SECURITY](../SECURITY.md).

### `[pack]`

| Key | Type | Default | Flag | Status | Effect |
| --- | --- | --- | --- | --- | --- |
| `min_phases` | int | `6` | — | active | Validation warns when the pack has fewer phases. |
| `max_phases` | int | `12` | — | active | Upper bound included in the model's instructions. |
| `include_deepseek_prompt` | bool | `true` | — | active | When `false`, `DEEPSEEK_START.md` is dropped from generation **and** validation. |
| `include_codex_review_prompt` | bool | `true` | — | active | When `false`, `CODEX_REVIEW_PROMPT.md` is dropped from generation and validation. |
| `include_review_checklist` | bool | `true` | — | active | When `false`, `REVIEW_CHECKLIST.md` is dropped from generation and validation. |

## CLI-only options

| Flag | Status | Effect |
| --- | --- | --- |
| `--dry-run` | active | Run the full pipeline but write nothing; print the planned files. |
| `--verbose` | active | Print extra diagnostics (to stdout — the runtime has no stderr). |
| `--debug` | active | Print sanitized provider/model/finish-reason/length diagnostics during `init`. |
| `--save-raw-response <file>` | active | Save raw model response to a file (warning: may contain sensitive data). |
| `--config <file>` | active | Use a specific `packwrite.toml` instead of the one in the cwd. |
| `--run-name <name>` | **reserved** | Sets `run_name`, reserved for the deferred `compare` command. |

## Environment variables

| Variable | Purpose |
| --- | --- |
| `KUJO` | Path to the Kujo interpreter (used by `bin/packwrite`). |
| `PACKWRITE_API_KEY` | Preferred API key; checked first for every provider. |
| `DEEPSEEK_API_KEY` / `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` | Provider-specific fallback keys. |
| `PACKWRITE_FAKE_RESPONSE_FILE` | Test/offline seam: file whose contents are used as the model response. |
| `PACKWRITE_FAKE_RESPONSE` | Test/offline seam: inline string used as the model response. |
| `PACKWRITE_DEBUG` | If `1`/`true`/`yes`, enables `init` debug diagnostics without `--debug`. |

API keys are read from the environment **only** — never from flags or config files.

## Precedence example

```toml
# packwrite.toml
[model]
provider = "openai"
model = "gpt-5.5"
```

```bash
packwrite init MEGA_PROMPT.md --model gpt-5.5-mini
# provider = openai   (from packwrite.toml)
# model    = gpt-5.5-mini   (flag overrides packwrite.toml)
```
