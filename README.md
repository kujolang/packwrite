# PackWrite

[![Version](https://img.shields.io/badge/version-1.1.1-black)](https://github.com/kujolang/packwrite/releases/tag/v1.1.1)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)
[![built with Kujo](https://img.shields.io/badge/built%20with-Kujo-white.svg)](https://github.com/kujolang/kujo)

**PackWrite turns a project brief into a validated execution pack for coding agents.**

Save your brief as `MEGA_PROMPT.md` and run PackWrite in your repository. It sends
the brief and a small repository summary to a model, then writes an `agent/` directory
with phase plans, acceptance criteria, handoff notes, and review prompts. PackWrite
checks the pack's structure and paths; you review its content before using it.

```text
strategy AI → MEGA_PROMPT.md → packwrite → /agent pack → implementation agent → reviewer
```

## Contents

- [Why PackWrite](#why-packwrite)
- [Readiness and scope](#readiness-and-scope)
- [Install](#install)
- [Quickstart](#quickstart)
- [Commands](#commands)
- [Configuration](#configuration)
- [Model / provider selection](#model--provider-selection)
- [Model response format](#model-response-format)
- [Generated `/agent` structure](#generated-agent-structure)
- [Security & privacy](#security--privacy)
- [Workflows](#workflows)
- [Output & exit codes](#output--exit-codes)
- [Documentation](#documentation)
- [Development](#development)
- [Project status](#project-status)
- [Contributing, security, license](#contributing-security-license)

## Why PackWrite

A large task needs a record of its scope, progress, and decisions. PackWrite keeps
that record beside your code:

- **`MASTER.md`** — stable project intent + assumptions (don't rewrite).
- **`phases/*.md`** — per-phase specs with scope, out-of-scope, and acceptance criteria.
- **`HANDOFF.md` / `DECISIONS.md`** — mutable state and a decision log.
- **`REVIEW_CHECKLIST.md`** — concrete, verifiable review items.
- **`DEEPSEEK_START.md` / `CODEX_REVIEW_PROMPT.md`** — ready-to-paste prompts for an
  implementation agent and an independent reviewer.

Code validates the required files, sections, and paths. The model writes the content.

## Readiness and scope

PackWrite creates local planning files. It does not implement your project, deploy
code, or coordinate concurrent writers. Review generated instructions before giving
them to an agent. Hosted authentication, organization policy, signing, and deployment
controls belong to the systems that run PackWrite.

Current hardening includes:

- Output directories must be relative, non-empty, non-traversing paths.
- Model manifest paths are validated before dry-runs or writes claim success.
- Secret-looking generated paths are rejected, not merely warned about after writing.
- Writes are staged and validated before promotion, with rollback on failed promotion.
- The full test suite is offline: 248 unit assertions and 116 CLI integration assertions.

## Install

PackWrite is written in the [Kujo language](#about-kujo) and run by the Kujo
interpreter. Install Kujo so the `kujo` command is available on your `PATH`:

```bash
# get the released source
git clone --branch v1.1.1 --depth 1 https://github.com/kujolang/packwrite.git
cd packwrite
./bin/packwrite --help

# or install the launcher on your PATH
make install                      # symlinks bin/packwrite into /usr/local/bin
packwrite --help
```

The destination `PREFIX/bin` must already exist and be writable. Set `PREFIX` to
choose a different install root, for example `make install PREFIX="$HOME/.local"`.
Installation returns a nonzero status if the symlink cannot be created.

The launcher preserves your working directory, so config discovery and the generated
`/agent` pack land where you invoke it.

## Quickstart

```bash
cd my-project
cat > MEGA_PROMPT.md <<'EOF'
# Demo

Build a small CLI that says hello, with tests and a README.
EOF

export PACKWRITE_API_KEY=sk-...                       # your provider key (env only)
packwrite doctor
packwrite init MEGA_PROMPT.md --dry-run
packwrite init MEGA_PROMPT.md --provider deepseek --model deepseek-v4-pro
packwrite validate
packwrite prompt deepseek         # paste into your implementation agent
```

A successful `init` prints:

```text
PackWrite generated an agent pack.

  Output:     agent/
  Provider:   deepseek
  Model:      deepseek-v4-pro
  Files:      13
  Phases:     6
  Validation: passed with 0 warnings

Next:
  packwrite prompt deepseek
```

`init` prints each stage, such as `[3/8] Collecting repository context...`.
Use `--quiet` to suppress successful progress and summary output.

`--dry-run` calls the model and validates the returned manifest without writing a
pack. It can incur provider charges:

```bash
packwrite init MEGA_PROMPT.md --dry-run
```

New here? Follow the full walkthrough in **[docs/HOWTO.md](docs/HOWTO.md)**.

## Commands

| Command | What it does |
| --- | --- |
| `packwrite init [file]` | Generate an `/agent` pack from a mega prompt |
| `packwrite validate` | Deterministically validate an existing `/agent` pack (`--json` for CI) |
| `packwrite summary` | Report pack status, phase count, missing files, warnings, and next command (`--json` supported) |
| `packwrite prompt deepseek` | Print the implementation-agent prompt |
| `packwrite prompt codex-review` | Print the reviewer prompt |
| `packwrite config` | Show the fully resolved configuration and its sources |
| `packwrite doctor` | Check config, provider, endpoint, API key, and prompt/output state (`--strict` gates CI; `--json` is machine-readable) |
| `packwrite help` / `version` | Help / version |

PackWrite supports top-level help/version aliases and command-specific `--help` for
`init`, `validate`, `summary`, `prompt`, `config`, and `doctor`.

### `init` options

```text
--provider <name>     deepseek | openai | local (OpenAI-compatible; others need --endpoint)
--model <name>        model identifier
--endpoint <url>      OpenAI-compatible chat-completions URL (overrides the preset)
--temperature <n>     sampling temperature (0.0–2.0)
--timeout <seconds>   request timeout (positive number)
--output <dir>        output pack directory (default: agent)
--overwrite           replace an existing pack directory (clean replace: stale files pruned)
--dry-run             parse + plan but write nothing
--config <file>       use a specific packwrite.toml
--verbose             extra diagnostics
--quiet               suppress successful progress and summary output
--debug               print sanitized provider/model/finish_reason diagnostics
--save-raw-response <file>  save raw model response (may contain sensitive data)
```

## Configuration

PackWrite reads `packwrite.toml` from the working directory. Resolution order, lowest to
highest precedence:

```text
defaults  <  global config (~/.config/packwrite/config.toml)  <  packwrite.toml  <  CLI flags
```

```toml
[prompt]
file = "MEGA_PROMPT.md"

[output]
dir = "agent"
overwrite = false
mode = "autopilot"          # reserved (parsed, not yet wired)

[model]
provider = "deepseek"
model = "deepseek-v4-pro"
temperature = 0.1
# endpoint = "https://api.deepseek.com/chat/completions"   # override the preset

[repo_context]
# include = top-level allow-list; omit for defaults, use [] for all eligible names
include = ["README.md", "Cargo.toml", "package.json", "pyproject.toml", "src", "tests", "docs"]
exclude = [".env", ".git", "node_modules", "vendor", "dist", "build", ".next", "coverage"]

[pack]
min_phases = 6              # validation warns below this
max_phases = 12             # included in the model instructions
include_deepseek_prompt = true        # generate + require DEEPSEEK_START.md
include_codex_review_prompt = true    # generate + require CODEX_REVIEW_PROMPT.md
include_review_checklist = true       # generate + require REVIEW_CHECKLIST.md
```

All keys above change observable behavior **except** `[output].mode` and `run_name`
(via `--run-name`), which are parsed but **reserved** for deferred features. Full table
with types, defaults, and flag mappings: **[docs/CONFIGURATION.md](docs/CONFIGURATION.md)**.
See also [`packwrite.example.toml`](packwrite.example.toml).

## Model / provider selection

Choose a provider and model with flags or config. PackWrite calls the Kujo
`ai_chat` builtin through an adapter.

**The adapter speaks only the OpenAI-compatible chat-completions protocol** (it posts
`{model, messages}`, authenticates with `Authorization: Bearer`, and reads
`choices[0].message.content`). Built-in endpoint presets therefore exist only for
providers that expose that protocol natively:

| `--provider` | Endpoint preset |
| --- | --- |
| `deepseek` | `https://api.deepseek.com/chat/completions` |
| `openai`   | `https://api.openai.com/v1/chat/completions` |
| `local`    | `http://localhost:11434/v1/chat/completions` |

Any other provider has **no preset** and must point `--endpoint` (or `[model].endpoint`)
at an OpenAI-compatible URL — a gateway such as OpenRouter or LiteLLM works well.

Set `--model` or `[model].model` to a model your endpoint supports. The default is
`deepseek-v4-pro`; check your provider's available models before running generation.

> **Anthropic is not supported natively.** Anthropic's API uses `/v1/messages` +
> `x-api-key`, which this adapter does not speak. `--provider anthropic` with no endpoint
> fails with a clear error; to use Claude, set `--endpoint` to an OpenAI-compatible
> gateway in front of it.

**API keys come from the environment only** — never from flags or committed config.
PackWrite checks `PACKWRITE_API_KEY` first, then a provider-specific variable
(`DEEPSEEK_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`).

## Model response format

PackWrite expects the model to return a **JSON file manifest** and nothing else:

```json
{ "files": [ { "path": "agent/MASTER.md", "content": "..." }, ... ] }
```

For DeepSeek structured pack generation, PackWrite requests strict JSON mode and
disables thinking by default:

```json
{
  "response_format": { "type": "json_object" },
  "thinking": { "type": "disabled" },
  "max_tokens": 32000,
  "temperature": 0.1
}
```

Parsing is tolerant — surrounding prose and ```` ``` ```` code fences are stripped — but
the payload must be valid JSON with a non-empty `files` array of `{path, content}`
string pairs whose paths stay inside the output directory. If the model returns prose
without a JSON object, you get `The model response could not be parsed into files.` with
sanitized diagnostics (provider/model/response length/head/tail/finish-reason hints)
to make failures actionable. There is no Markdown-fallback parser in v1.

## Generated `/agent` structure

```text
agent/
  MASTER.md               stable project intent + assumptions (don't rewrite)
  TODO.md                 phase checklist linking each phase file
  HANDOFF.md              mutable status, updated after every phase
  DECISIONS.md            confirmed / open / log
  REVIEW_CHECKLIST.md     concrete, verifiable review items
  DEEPSEEK_START.md       implementation-agent prompt
  CODEX_REVIEW_PROMPT.md  reviewer prompt
  phases/
    00-project-brief.md
    01-<slug>.md ... NN-<slug>.md
```

## Security & privacy

PackWrite is conservative about what leaves your machine:

- **API keys are read from the environment only** — never from flags, config, or logs.
- **The model receives your mega prompt and a bounded repository summary:** the root
  name, a one-line README excerpt, detected languages, and included file/directory
  names. PackWrite does not upload the full checkout. Keep sensitive data out of the
  prompt and README excerpt.
- **Secrets are excluded by default** (`.env*`, `*.pem`, `*.key`, `id_rsa`,
  `id_ed25519`, `.git`, `node_modules`, `vendor`, `dist`, `build`, `.next`, `coverage`,
  `target`, `.venv`, and names containing `secret`/`token`); skipped paths are reported.
- **Generated paths are restricted** to the output directory (absolute, `..` traversal,
  backslash-separator, `~` home-expansion, control-character, ambiguous-segment, and
  escaping paths are rejected), configured output directories must be relative project
  paths with no existing symlink components, and generated secret-looking paths are
  rejected. Model responses and generated content have explicit resource ceilings.
- **Prompt payloads are never logged.** `--verbose` reports size only. Explicit raw
  response saves are owner-only, atomic, and refuse to overwrite an existing path.
- **Malformed CLI input fails cleanly** — bad or out-of-range `--temperature` /
  `--timeout` values return an actionable error instead of crashing the runtime.

Details and reporting: **[SECURITY.md](SECURITY.md)**.

## Workflows

**Autonomous implementation.** `agent/DEEPSEEK_START.md` tells the implementation agent
to run on autopilot: read the pack → implement the first incomplete phase → update
`HANDOFF`/`DECISIONS`/`REVIEW_CHECKLIST` → mark the TODO item → continue to the next
phase without human approval → repeat until done, stopping only for defined blockers.

**Independent review.** When implementation is finished, hand a reviewer
`agent/CODEX_REVIEW_PROMPT.md`. It asks for an overall score, category scores, a
comparison against the mega prompt, scope drift, bugs, missing tests, security issues,
and a step-by-step repair checklist.

## Output & exit codes

The Kujo runtime has no separate stderr, so **all output goes to stdout**, prefixed so
categories stay greppable: `warning (...)`, `! ` (validation warnings), `note:`, and
`error:`. Exit codes: `0` success, `1` operational failure, `2` usage error.
`packwrite prompt <target>` prints the prompt verbatim so it pipes cleanly.
A missing prompt uses the built-in fallback. Existing unreadable files, directories,
and symlinks return an operational error instead of emitting a fallback.

## Documentation

| Doc | What's in it |
| --- | --- |
| [docs/HOWTO.md](docs/HOWTO.md) | End-to-end walkthrough + recipes |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Every config key, type, default, and flag |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Module map, data flow, extension points |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Every error message and its fix |
| [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md) | Current prioritized backlog for upcoming work |
| [docs/PROVIDERS.md](docs/PROVIDERS.md) | Provider and gateway compatibility matrix |
| [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) | Repeatable official-release gate |
| [AGENTS.md](AGENTS.md) | Orientation for coding agents working on PackWrite |

Canonical copyable examples live in this README, [docs/HOWTO.md](docs/HOWTO.md), and
[`packwrite.example.toml`](packwrite.example.toml). Test fixtures are behavior
contracts, not style examples.

## Development

```bash
make test       # kujo check on every file + the full offline suite
make check      # lint only
make help       # list tasks
```

The suite (248 unit + 116 CLI integration assertions) is **fully offline** — AI calls go
through a fake-injection seam (`PACKWRITE_FAKE_RESPONSE_FILE`), so no API key or network
is required. The 24 permission assertions skip under root. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and the Kujo runtime
conventions.

Root files are intentionally kept for project entrypoints and governance:
`packwrite.kujo` is the CLI entrypoint, `bin/packwrite` is the launcher, `Makefile`
drives developer tasks, `kujo.toml` identifies the Kujo package, and
`packwrite.example.toml` is the canonical copyable config. Runtime logic lives under
`src/`; tests live under `tests/`; user/developer docs live under `docs/`.

## Project status

**Implemented in v1:** `init`, `validate`, `summary`, `prompt`, `config`, `doctor`, `help`,
`version`.

**Planned / not implemented** (running them prints a "planned for a future version"
message and exits non-zero): `compare`, `repair-pack`. Also deferred: a
Markdown-delimiter fallback parser (v1 is JSON-manifest only) and streaming output. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#extension-points).

## Contributing, security, license

- **Contributing:** [CONTRIBUTING.md](CONTRIBUTING.md) — setup, conventions, Kujo gotchas, PR process.
- **Security:** [SECURITY.md](SECURITY.md) — security model and private reporting.
- **Changelog:** [CHANGELOG.md](CHANGELOG.md).
- **License:** [MIT](LICENSE) © 2026 Robert DeVore.

## About Kujo

PackWrite is a standalone tool in the **Kujo** ecosystem (alongside RunLedger, Howl,
Yard, and others). It is written in the Kujo language and depends only on the Kujo
interpreter; it lives in its own repository and does not modify the Kujo language repo.
