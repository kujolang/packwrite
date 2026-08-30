# HOWTO: From idea to an agent-ready pack

This is an end-to-end walkthrough of the PackWrite workflow. It assumes you have a
`kujo` binary on your `PATH` (or put `bin/packwrite` on your `PATH`). See the
[README](../README.md) for install details.

```bash
alias packwrite='/path/to/packwrite/bin/packwrite'   # convenience for this guide
```

---

## 1. Write a mega prompt

Brainstorm the project with a strategy AI, then save the result as `MEGA_PROMPT.md` in
your repo. It should describe *what* you want built and the guardrails — not the code.
A good mega prompt covers: the project's purpose, the target user, the main use cases,
explicit non-goals, architecture principles, and a definition of done.

```bash
cd my-project
$EDITOR MEGA_PROMPT.md
```

There is no required schema; PackWrite distills whatever you write into a structured
pack. Bigger, clearer intent yields a better pack.

## 2. (Optional) Add a config file

Defaults work out of the box. To pin a provider/model or tweak behavior, drop a
`packwrite.toml` in the repo (copy [`packwrite.example.toml`](../packwrite.example.toml)).
See the [Configuration reference](CONFIGURATION.md) for every key.

```toml
[model]
provider = "deepseek"
model = "deepseek-v4-pro"
temperature = 0.1
```

## 3. Check your setup

`doctor` confirms PackWrite can find your prompt, resolve an endpoint, and see an API
key — before you spend a model call.

```console
$ packwrite doctor
PackWrite doctor
  cwd:             /Users/you/my-project
  provider:        deepseek
  model:           deepseek-v4-pro
  endpoint:        https://api.deepseek.com/chat/completions
  api key:         missing (set PACKWRITE_API_KEY or a provider key)
  prompt file:     MEGA_PROMPT.md (found)
  output dir:      agent/ (absent)
```

Set the key it asks for:

```bash
export PACKWRITE_API_KEY=sk-...      # or DEEPSEEK_API_KEY / OPENAI_API_KEY
```

If model output parsing fails, re-run with sanitized debug diagnostics:

```bash
PACKWRITE_DEBUG=1 packwrite init MEGA_PROMPT.md --provider deepseek --model deepseek-v4-pro
```

To inspect the raw model payload intentionally, add `--save-raw-response <file>`.
Use this carefully because raw responses can contain sensitive data. PackWrite creates
the file with owner-only permissions and refuses to overwrite an existing path.

## 4. Preview without writing (recommended first run)

`--dry-run` runs the whole pipeline — context collection, the model call, manifest
parsing — but writes nothing. It prints the files it *would* create.

```console
$ packwrite init MEGA_PROMPT.md --dry-run
Dry run: would write 13 files (6 phases) to agent/
    agent/MASTER.md
    agent/TODO.md
    ...
```

## 5. Generate the pack

```console
$ packwrite init MEGA_PROMPT.md
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

What happened, in order: config resolved → mega prompt located → overwrite guard
checked → safe repo context collected → distillation prompt built → model called via
the adapter → JSON manifest parsed → pack written → pack validated → summary printed.

Inspect an existing pack without contacting a provider:

```bash
packwrite summary
packwrite validate --json
packwrite doctor --strict --json
```

Each `--json` form emits one JSON object. Use `packwrite init --quiet` when successful
generation should produce no progress or summary output; errors remain visible.

The result:

```text
agent/
  MASTER.md  TODO.md  HANDOFF.md  DECISIONS.md  REVIEW_CHECKLIST.md
  DEEPSEEK_START.md  CODEX_REVIEW_PROMPT.md
  phases/00-project-brief.md  phases/01-*.md ... phases/NN-*.md
```

> Re-running `init` refuses to clobber an existing `agent/` unless you pass
> `--overwrite`, which performs a **clean replace** (stale files from the old pack are
> pruned).

## 6. Validate the pack

`init` already validates, but you can re-check any time. Validation is deterministic
and never calls the model.

```console
$ packwrite validate
Validation passed (0 warnings) for agent/
```

If something is off, you get specific, actionable errors (e.g. a `TODO.md` link to a
missing phase file) and quality warnings (e.g. a phase missing its `Suggested checks`
section). See [TROUBLESHOOTING](TROUBLESHOOTING.md).

## 7. Hand it to an implementation agent

Print the implementation prompt and paste it into your coding agent
(DeepSeek, Codex, Claude, a local model, …):

```bash
packwrite prompt deepseek
```

The prompt tells the agent to read the pack, implement the first incomplete phase,
update `HANDOFF.md` / `DECISIONS.md` / `REVIEW_CHECKLIST.md`, mark the TODO item, and
continue phase by phase without waiting for approval — stopping only for defined
blockers.

## 8. Review the result

When the agent finishes, hand a reviewer the review prompt:

```bash
packwrite prompt codex-review
```

It asks for an overall score, category scores, a comparison against the mega prompt,
scope drift, bugs, missing tests, security issues, and a step-by-step repair checklist.

---

## Recipes

### Compare models by hand

Generate two packs into different directories and diff them:

```bash
packwrite init MEGA_PROMPT.md --provider deepseek --model deepseek-v4-pro --output agent-deepseek
packwrite init MEGA_PROMPT.md --provider openai   --model gpt-5.5      --output agent-openai
diff -r agent-deepseek agent-openai
```

(A first-class `compare` command is planned but not yet implemented.)

### Use a non-preset provider (e.g. via a gateway)

The adapter speaks the OpenAI-compatible chat protocol only. Point `--endpoint` at any
compatible URL — including a gateway in front of Claude or Gemini:

```bash
export PACKWRITE_API_KEY=...
packwrite init MEGA_PROMPT.md --provider openrouter \
  --endpoint https://openrouter.ai/api/v1/chat/completions \
  --model anthropic/claude-3.7-sonnet
```

### Slim the pack

Skip the optional files for a leaner pack (these are dropped from both generation and
validation):

```toml
[pack]
include_review_checklist = false
```

### Drive PackWrite in CI / tests without a model

Feed a canned manifest through the offline seam (this is how PackWrite tests itself):

```bash
export PACKWRITE_FAKE_RESPONSE_FILE=/path/to/manifest.json
packwrite init MEGA_PROMPT.md
```
