# PackWrite repository hardening — October 12, 2026

## Scope and provenance

- Repository: `kujolang/packwrite`; branch: `main`; initially clean.
- Starting SHA: `3f0cbf4b5052677d22040cdf486adf2817b40a20`.
- Ending implementation SHA: `b520d2d94e69e97b53de51450c603ff7a85128c0`.
  The following documentation commit records this report and its evidence; its
  identity is available with `git log -1 --format=%H -- docs/audits/2026-10-12-hardening.md`.
- Purpose: compile project intent and filtered repository context into validated
  Markdown execution packs for downstream agents.
- Dependencies: Kujo builtins, Bash, Make, `mv`/`rm`/`chmod`; tests also use `mktemp`,
  `ln`, and `touch`. No package dependencies were added or removed. Local verification
  used Kujo 1.5.0 on macOS arm64. CI pins setup-kujo by commit and requests v1.2.2.
- Integration evidence: Relay calls `init ... --output agent --overwrite`; Tribunal
  imports `context_collect`/`context_render` through its bridge. Their source was
  inspected read-only. No sibling repository was modified.

This is a source-backed engineering audit, not live-provider certification. Reviewed
all nine source modules, entrypoint, launcher, configuration/spec, unit/CLI fixtures,
golden pack, Make targets, both workflows and artifact guard, historical benchmark
harness/results, canonical docs, security policy, and agent instructions. Historical
benchmark evidence and the August audit remain unchanged.

## Baseline

`make test` passed: 182 unit and 66 CLI assertions, static checks for all Kujo source
and test files, and the existing Bash gate; 22.08 seconds elapsed. No baseline suite
failure existed. Additional probes exposed gaps in what that suite proved:

- Replacing `agent/MASTER.md` with a directory still returned validation JSON
  `{"errors":[],"ok":true,"warnings":[]}` and exit 0.
- Passing a malformed second script to `make scripts` still exited 0: `bash -n`
  accepts one script; subsequent arguments were script arguments.
- A 2,000-file `src` subtree produced 36,298 context bytes / 2,014 lines.
- Unicode nested output `生成/計画` succeeded on the installed runtime. The suspected
  Unicode failure was not reproduced, so its slicing implementation was preserved.

Exact timing samples, baseline probe receipts, environment, and payload measurements
are in [the evidence JSON](evidence/2026-10-12.json).

## Changes and proof

| Problem / root cause | Implementation / files | Regression proof | Compatibility and measured impact |
| --- | --- | --- | --- |
| README and stack detection bypassed the listing allow/exclude policy; links could expose outside context | Apply one eligibility check to optional file reads/detection, skip symlink entries; `src/repo_context.kujo` | Include/exclude tests for README and stack; symlink README/directory tests | Explicit privacy settings now apply consistently; symlink context intentionally omitted |
| One-level context was depth-limited but not width-limited; README was read in full regardless of size | Sorted 100-entry top/child lists, 12 subtrees, explicit omitted counts, 20 skip warnings, 64 KiB pre-read README ceiling | Top-level/subtree budget, exact omission count, ordering, visible notice, oversized README tests | Only supplemental context is abbreviated; mega prompt unchanged; measured context 36,298 → 2,226 bytes |
| Presence checks treated directories as required files; validation followed links and scanned secrets only at root | Require readable nonempty regular required files; skip linked phases; iterative recursive scan rejects symlinks, special files, and secret-looking paths; `src/validate.kujo` | Directory/empty/symlink required docs, nested secrets, cycle, directory phase-count tests | Valid pack layout unchanged; invalid existing packs now fail with exit 1 and structured errors |
| TODO parser silently ignored references after 1,000; basename normalization accepted invalid nested links | Consume all references; require actual direct phase references in manifest and disk checks; `src/pack.kujo`, `src/validate.kujo` | 1,002-reference extraction and nested-link rejection | Broken links are intentionally rejected; documented direct `phases/*.md` references unchanged |
| Known TOML sections of wrong type silently fell back; explicit missing config also fell back; read failures escaped envelopes | Validate known section tables, reject missing explicit config, reuse guarded regular-file/UTF-8 reads; `src/config.kujo`, `src/prompt.kujo`, `src/util.kujo` | Wrong section, unknown extension preservation, missing explicit config, directory prompt/config tests | Missing default/global config stays optional; unknown extension tables preserved; valid configuration unchanged |
| Shell gate only checked first script; unit tests shared a fixed directory and interpolated paths into shell commands | Loop over all shell inputs, include benchmark scripts, use `mktemp` plus argument-vector subprocesses; `Makefile`, both test harnesses | Malformed second-script regression; two concurrent 209-assertion runs with one TMPDIR containing spaces, no leftover directories | No product dependency change; unit runs no longer remove each other's workspaces |
| Agent docs referred to removed `write_text` helper and old test totals | Correct helper name/atomic semantics and totals; configuration, security, changelog, architecture, contributor and agent docs | Source/doc cross-check and `git diff --check` | Documentation only |

No dead code or dependencies were removed on appearance alone. Existing module
boundaries and quiet/JSON CLI surfaces were retained. Repeated small-pack validation
reads were reviewed; no cache, concurrency layer, or broad rewrite was justified.

## Measurements

Three sequential samples per variant, same runtime and fixture; baseline from
`git archive` of the starting SHA, current from the working implementation. These are
local observations under shared host load, not universal performance guarantees.

| Dimension | Before | After | Interpretation |
| --- | --- | --- | --- |
| 2,000-child context bytes / lines | 36,298 / 2,014 | 2,226 / 117 | Explicit summary budget, not silent loss |
| Complete distillation prompt bytes | 39,202 | 5,130 | Same mega prompt; no model-token estimate claimed |
| Context probe median elapsed | 6.565 s | 6.199 s | Ranges overlap; no speedup claim |
| Ordinary 13-file offline init median | 0.613 s | 0.619 s | Similar local observation; stronger checks |
| Ordinary validation median | 0.158 s | 0.164 s | Small added checking cost; no speedup claim |
| Quiet successful init output | 0 bytes | 0 bytes | Preserved |
| Golden validation JSON output | 38 bytes | 38 bytes | Preserved |
| Generated 13-file pack | Baseline | Byte-identical | No artifact-format drift |
| Full suite assertion count | 248 | 276 | 27 unit + 1 CLI regressions added |
| Package dependencies | 0 | 0 | Unchanged |

Memory/CPU peaks and binary size were not measured: this pass changes interpreted
source, not a compiled distribution. Context emission is bounded, but `list_dir`
still materializes each directory's names and filtering visits them all; the result
is a payload bound, not a claim of constant-memory directory enumeration.

### Reproduce context measurements

Use an isolated directory with `MEGA_PROMPT.md` containing `Build a demo.`, no README,
and `src/file-0000.txt` through `src/file-1999.txt` (empty files). For each checkout,
set `KUJO_MODULE_PATH` to that checkout and run:

```bash
kujo run benchmarks/hardening/scripts/prompt_probe.kujo -- /path/to/context
```

The fixture basename was `context`; changing it changes payload bytes. Record three
elapsed samples and the probe's JSON. For ordinary CLI comparison, generate the fake
response with `tests/fixture.kujo`, set `PACKWRITE_FAKE_RESPONSE_FILE`, and run
`init --quiet --overwrite` followed by `validate --json` three times in isolated
workspaces. Compare every generated file byte-for-byte.

## Trust boundaries and failure review

Reviewed CLI/config/env inputs, model request/options and error handling, tolerant
JSON extraction and manifest ceilings, secret/path filtering, file reads, atomic file
writes, stage/backup promotion and rollback, orphan cleanup, subprocess argv, output
and diagnostics, and downstream pack consumption. The tool never executes model
commands. Credentials remain environment-only; no live request or credential was used.

Fixed read-policy bypass, linked context disclosure, false-positive pack validation,
nested secret/symlink acceptance, silent configuration fallback, partial phase-link
validation, and a false-positive verification gate. Tests cover successful behavior
and each practical failure boundary. Existing response bounds, atomic raw saves,
overwrite refusal, rollback/recovery preservation, endpoint checks, and exact CLI
help remain covered by the full offline suite.

Remaining boundaries are explicit: prompt text and ordinary README text are user
content, not a secret detector; structural validation does not prove generated plan
quality. Existing filesystem check/use races against a hostile concurrent writer are
not eliminated by these path checks. This pass does not claim multi-writer pack
transactions or live-provider retry guarantees.

## Public contracts and external consumers

- Public signatures: unchanged. `context_collect` adds omission metadata to its
  summary/subtree dictionaries; consumers using its exported renderer remain valid.
- CLI commands/help/exit-code classes: unchanged. Invalid config/pack inputs that
  previously passed now return operational failure. Context warnings are bounded.
- Generated Markdown, model JSON manifest, `validate/summary/doctor` JSON schemas:
  unchanged. Golden generated output is byte-identical.
- Config keys and environment variables: unchanged; invalid known sections and
  explicit missing config are rejected. Defaults retain their precedence.
- Tribunal receives filtered, bounded Markdown through its unchanged bridge contract.
  Relay's generation invocation and fixture remain compatible. No ecosystem migration
  or sibling-repository change is required.

## Verification and remaining work

Passed: `make test` (209 unit + 67 CLI assertions), `make smoke`, shell syntax checks,
`git diff --check`, artifact guard, two concurrent unit suites with spaced TMPDIR,
and the byte-identical pack comparison. Tribunal's interpreter bridge returned
valid bounded context and Relay's offline fixture generated successfully.

The first hosted run (`38336649994`) exposed a test-cleanup compatibility difference:
Kujo 1.2.2 `delete_file` refuses a symlink whose target is a directory, while local
1.5.0 removes it. The cycle regression now uses argument-vector `rm` to unlink its
own fixture, preserving the same assertion and the pinned CI runtime. This follow-up
changes test cleanup only; product implementation and measurements remain at the
ending implementation SHA above. The full suite includes fake generation,
raw-response refusal/mode, symlink output, nested overwrite/pruning, recovery backup,
config precedence, malformed response diagnostics, and JSON/quiet/help contracts.

- P0/P1: no unresolved issue established within the reviewed supported workflow.
- P2 deferred boundary: hostile concurrent modification of a pack tree remains outside
  the race-free guarantee; descriptor-relative operations would require a separate
  compatibility review of the minimum Kujo runtime. No external change is required
  for the fixes here.
- P3 / not worth changing now: validation read caching, speculative retries, provider
  protocol redesign, broad parser/module rewrites, and historical evidence churn.
- Live-provider interoperability and production filesystem fault injection were not
  exercised. Offline fixtures are not live certification.
