# Troubleshooting

Every PackWrite error is actionable and sets a non-zero exit code (`1` operational,
`2` usage). The Kujo runtime has no stderr, so messages print to stdout with prefixes
(`error:`, `warning`, `! `, `note:`). Run `packwrite doctor` first when something is
off — it summarizes provider, endpoint, API key, and prompt/output state.

## Launcher

**`packwrite: cannot find the Kujo interpreter ('kujo').`** (exit 127)
The `bin/packwrite` wrapper can't find a Kujo binary. Set `KUJO` to its path:
```bash
export KUJO=/path/to/kujo/target/release/kujo
```

## Mega prompt

**`Could not find MEGA_PROMPT.md. Pass a file path or set [prompt].file in packwrite.toml.`**
No prompt file was found. Pass one explicitly (`packwrite init path/to/prompt.md`) or set
`[prompt].file` in `packwrite.toml`.

**`Mega prompt path is a directory, not a file: ...`** — you pointed at a directory.

**`Mega prompt is empty: ...`** — the file exists but has no content.

## Provider / model / endpoint

**`The selected provider/model was not available through the AI SDK (provider=…, model=…). No endpoint is configured for provider '…'.`**
The provider has no built-in preset. Use `deepseek`, `openai`, or `local`, or set
`--endpoint` / `[model].endpoint` to an OpenAI-compatible chat-completions URL.

**`… '…' is not supported natively. Set --endpoint … to an OpenAI-compatible gateway URL.`**
You selected a provider whose native API isn't OpenAI-compatible (e.g. `anthropic`).
The adapter only speaks the OpenAI chat protocol. Point `--endpoint` at a compatible
gateway. See the README's *Model / provider selection* section.

**`… The AI SDK call failed.` / `… <transport error>` / `The AI SDK returned an empty response.`**
The request reached the adapter but failed. Check the endpoint URL, that
`PACKWRITE_API_KEY` (or a provider key) is exported, network access, and that the model
name is valid for that endpoint. `packwrite doctor` shows whether a key is detected.

## Model response

**`The model response could not be parsed into files.`** (with a parenthetical reason)
The model didn't return the expected JSON manifest. Common causes and fixes:

| Reason | Meaning | Fix |
| --- | --- | --- |
| `(invalid JSON)` | Not parseable as JSON. | Lower `--temperature`; try another model; retry. |
| `(expected a JSON object)` | Top-level wasn't an object. | Same as above. |
| `(missing "files" array)` | No `files` key. | The model ignored the format; retry / different model. |
| `("files" must be a non-empty array)` | Empty `files`. | Retry; check the mega prompt isn't empty. |
| `(file entry N missing path/content)` | An entry lacked `path` or `content`. | Retry. |
| `(file entry N path/content not strings)` | Wrong types. | Retry. |

PackWrite strips code fences and can extract one obvious top-level JSON object from
surrounding prose. If parsing still fails, the error now includes sanitized diagnostics:

- provider and model
- response length and emptiness
- first/last 500 characters (sanitized)
- `finish_reason` and a truncation hint when `finish_reason=length`

Use these to tell whether the response was truncated, wrapped, or not emitted in JSON mode.
For quick local diagnostics, run:

```bash
PACKWRITE_DEBUG=1 packwrite init MEGA_PROMPT.md --provider deepseek --model deepseek-v4-pro
```

To persist the raw response for offline debugging, use `--save-raw-response <file>`.
This is opt-in because raw content may contain sensitive data.

## Writing the pack

**`Refusing to overwrite existing agent directory. Use --overwrite to replace it.`**
An output dir already exists. Re-run with `--overwrite` (a clean replace that prunes
stale files) or set `[output].overwrite = true`. Use a different `--output` dir to keep
both.

**`Unsafe manifest path (absolute|traversal): …` / `Manifest path escapes output dir '…': …`**
The model proposed writing outside the output directory. PackWrite refuses and writes
nothing. This is a safety guard; retrying usually yields a clean manifest.

## Validation

`packwrite validate` (and the validation step of `init`) reports **errors** (the pack is
unusable) and **warnings** (quality concerns). Errors fail the command; warnings don't.

**`Output pack directory not found: …`** — no pack at the resolved `--output` dir. Run
`init` first, or point `--output` at the right directory.

**`Missing required file: agent/X`** — a required file is absent. Note that the
`[pack].include_*` toggles control which prompt files are required.

**`Validation failed: TODO.md references missing phase file agent/phases/X`** — the
`TODO.md` links a phase file that doesn't exist. Re-run `init`, or add/rename the file.

**`Phase X missing section: ## …` / `Phase X has no acceptance criteria checkboxes`** — a
phase file is missing a required heading or any `- [ ]` items. Re-`init` or edit the file.

**`HANDOFF.md missing expected section: …` / `DECISIONS.md missing expected section: …`**
A structured file is missing an expected section. Re-`init` or edit.

**Common warnings** (safe to ship, worth a look): phase count below
`[pack].min_phases`; thin acceptance criteria; a phase missing a recommended section
(`Read before starting`, `Implementation notes`, `Suggested checks`, `Handoff
requirements`); `DEEPSEEK_START.md` lacking an autonomy cue; `CODEX_REVIEW_PROMPT.md`
lacking score/repair cues; potential placeholder text.

## Commands

**`error: '<cmd>' is planned for a future version and is not implemented yet.`** (exit 2)
`compare`, `repair-pack`, and `summary` are recognized but not implemented yet.

**`error: unknown command '<cmd>'`** (exit 2) — typo or unsupported command. Run
`packwrite help`.

**`error: unknown prompt target '<x>'. Valid targets: deepseek, codex-review`** — only
`deepseek` and `codex-review` are valid for `packwrite prompt`.

## Config

**`Could not parse TOML config at <path>` / `Config at <path> did not parse to a table`**
Your `packwrite.toml` (or global config) is malformed. Validate the TOML syntax. Use
`packwrite config` to see which sources were loaded.

## Still stuck?

Run with `--verbose` for extra diagnostics, confirm `kujo check` passes on a dev build,
and see [CONTRIBUTING.md](../CONTRIBUTING.md) for the runtime quirks. For a suspected
security issue, follow [SECURITY.md](../SECURITY.md) instead of opening a public issue.
