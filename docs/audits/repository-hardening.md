# Repository Hardening Audit

Audit date: 2026-08-30

## Repository

- Repository: `kujolang/packwrite`
- Branch: `main`
- Starting SHA: `f63425187d39580b36032b1f31731e3f086db9f1`
- Ending implementation SHA: `149a00497551fbdd1ba4022ef8cdc8d17b7b25b9`
  (the audit-receipt documentation commit follows this implementation commit)
- Purpose: compile a repository mega prompt and lightweight context into a validated,
  deterministic agent execution pack.
- Important dependencies/integrations: Kujo interpreter 1.0.0 and its `ai_chat`
  builtin, Bash 3.2+, Make, OpenAI-compatible chat-completions endpoints, GitHub
  Actions, and downstream agents that consume the generated Markdown pack.

## Baseline

The repository started clean on `main` at the starting SHA. Source, tests, launcher,
CI, documentation, configuration, model boundary, path/write logic, validation,
fixtures, and agent instructions were reviewed.

| Check | Baseline result |
| --- | --- |
| `make check` | Passed; 0.96 s real; 7,659,520-byte maximum RSS |
| `make test` | Passed; 144 unit + 47 CLI assertions; 31.94 s real; 21,749,760-byte maximum RSS |
| Nested `--output build/agent` | Failed during staged promotion because the destination parent did not exist |
| 1,620,000-byte invalid provider response | Did not complete within 37 seconds and was manually terminated |
| Dependency surface | No package dependencies; Kujo 1.0.0; pinned `actions/checkout` v4.4.0 and v5.1.0 commits |

The large-invalid-response probe used 20,000 ordinary non-secret text lines and the
offline fake-response seam. No live provider or credentials were used.

## Findings

| ID | Priority | Area | Finding | Evidence | Action | Status |
| --- | --- | --- | --- | --- | --- | --- |
| PW-H01 | P1 | Correctness | Documented nested output directories could not be promoted on first write. | Reproduced `Filesystem move failed ... No such file or directory` for `build/agent`. | Stage and back up as siblings of the final directory; create/recheck the parent. | Fixed |
| PW-H02 | P1 | Security | Existing or dangling symlink components could redirect nested output staging outside the project. | Path validation was lexical only; regression probes covered live and dangling links. | Reject every existing symlink component before generation and immediately before promotion. | Fixed |
| PW-H03 | P1 | Config/correctness | Parseable TOML types were trusted; the string `"false"` is truthy and could enable overwrite behavior. | `apply_toml` assigned raw values with no post-layer schema validation. | Validate all active config types, numeric ranges, arrays, booleans, and phase ordering. | Fixed |
| PW-H04 | P1 | Performance/DoS | Invalid non-JSON diagnostics scanned and rebuilt the full provider response. | 1.62 MB probe exceeded 37 s before termination. | Use native brace prechecks and sanitize only bounded diagnostic previews. | Fixed |
| PW-H05 | P1 | Resource safety | Model responses, file count, file size, total output, and path size were unbounded. | No ceilings existed before JSON parsing or manifest application. | Add explicit 16 MiB response/total, 512-file, 2 MiB/file, and 4096-byte path limits. | Fixed |
| PW-H06 | P1 | Sensitive output | Raw-response saves could overwrite existing paths, followed default file permissions, and ignored write failure. | `write_file(path, text)` was called directly. | Use atomic no-overwrite/no-symlink writes with mode `0600`; fail clearly on refusal. | Fixed |
| PW-H07 | P2 | Prompt/context safety | Repository filenames with line controls could enter model-visible context; project data lacked an explicit instruction-boundary rule. | Context rendered raw names and was appended without delimiters. | Skip control-bearing names, delimit context, and instruct the model to treat project content as untrusted data. | Fixed |
| PW-H08 | P2 | Network/output safety | Malformed or credential-bearing endpoints reached the SDK, and raw provider errors reached terminal output. | Endpoint was checked only for presence; `Err(e)` was concatenated into the error. | Require plain HTTP(S) endpoints without embedded credentials/line controls and return a stable provider error. | Fixed |
| PW-H09 | P2 | Failure semantics | Staged write return values were ignored. | `write_file_atomic(...)` result was discarded. | Abort, clean the stage, and identify the failed relative file. | Fixed |
| PW-H10 | P2 | Documentation | Security support version, test counts, help support, verbose behavior, and backlog state had drifted. | Docs claimed 0.1.x support, old assertion totals, payload logging under verbose, and missing subcommand help. | Reconcile canonical docs, security policy, changelog, and backlog. | Fixed |
| PW-H11 | P2 | CI ratchet | Bash scripts had no syntax gate in the default test target. | `make test` checked Kujo and runtime tests only. | Add `make scripts` and make it a prerequisite of `make test`. | Fixed |
| PW-H12 | P1 | CI/supply chain | Hosted CI intentionally failed until a Kujo binary source was configured. | The original workflow contained only placeholder setup options followed by fail-fast detection. Kujo v1.1.0 subsequently published a Linux x64 artifact and checksum. | Download the versioned release artifact, verify its pinned SHA-256 digest, and install it only after verification. | Fixed in follow-up |

## Changes Implemented

### Output transaction and filesystem boundary

- Problem/root cause: staging names embedded the full nested output path and promotion
  assumed the destination parent already existed; lexical checks did not account for
  symlinks.
- Implementation: stage/backup directories now sit beside the final output directory;
  parents are created before staging; live and dangling symlink components are rejected
  twice; stage/backup namespace exhaustion fails safely; file-write failures abort and
  clean up; orphan counting does not recurse through symlinked directories.
- Files: `src/pack.kujo`, `src/util.kujo`.
- Tests: nested first write, nested overwrite/prune, live symlink, dangling symlink,
  control/backslash/home path cases, and end-to-end CLI coverage.
- Compatibility: ordinary `agent` output and nested relative output remain supported.
  Outputs that depend on symlink traversal or ambiguous/control-bearing paths are now
  intentionally rejected.

### Config and endpoint validation

- Problem/root cause: TOML parsing proved syntax, not schema; raw values flowed into
  truthiness, comparisons, lists, and the model SDK.
- Implementation: validate resolved config after all precedence layers; require the
  documented types/ranges; enforce positive ordered phase bounds; require HTTP(S)
  endpoints without URL userinfo or line controls.
- Files: `src/config.kujo`, `src/ai.kujo`, `src/cli.kujo`.
- Tests: wrong boolean/list/numeric types, inverted bounds, invalid scheme, and embedded
  credentials.
- Compatibility: valid documented configuration is unchanged. Previously accepted
  invalid types and malformed endpoints now fail early with actionable errors.

### Untrusted model response bounds and diagnostics

- Problem/root cause: tolerant extraction and diagnostic sanitization did repeated
  character scans and rebuilt arbitrary response bodies; manifest amplification was
  unbounded.
- Implementation: use native brace detection for obvious non-JSON; bound response,
  manifest, file, total-content, and path sizes; sanitize the first/last preview only,
  omitting the tail for large responses.
- Files: `src/pack.kujo`.
- Tests: manifest file-count ceiling and existing parser/failure contracts.
- Compatibility: normal packs are far below the limits. Oversized model output now
  fails deterministically instead of consuming unbounded resources.

### Sensitive diagnostics and agent context

- Problem/root cause: raw responses used ordinary direct writes, provider errors were
  echoed, and repository names/project content were not explicitly bounded as data.
- Implementation: private atomic raw writes; stable provider failures; context control
  filtering and delimiters; one explicit untrusted-project-data rule.
- Files: `src/util.kujo`, `src/cli.kujo`, `src/ai.kujo`, `src/repo_context.kujo`.
- Tests: raw file mode/no-overwrite, control filename filtering, and prompt rule.
- Compatibility: prompt semantics and manifest schema are unchanged. The raw-save
  warning and provider failure wording changed intentionally for safety.

### Verification and documentation ratchets

- Added Bash syntax validation to `make test`.
- Updated README, security policy, architecture/configuration/HOWTO/troubleshooting,
  changelog, backlog, and repository agent guidance.
- Added this immutable audit receipt.

## Performance & Efficiency

| Measurement | Before | After | Interpretation |
| --- | --- | --- | --- |
| Invalid 1,620,000-byte provider response | Exceeded 37 s; manually terminated | 2.17 s real; 27,136,000-byte maximum RSS | Bounded diagnostic work; no ratio claimed because the baseline did not complete |
| Full verification suite | 31.94 s; 191 assertions | 73.41 s; 226 assertions plus Bash syntax | Gate is intentionally broader; this is not a product-runtime regression comparison |

The output-size ceilings prevent amplification but are safety bounds, not throughput
claims. No memory improvement is claimed. Dependency count remains zero. No token-count
claim is made: the generation prompt adds one short safety rule and two context
delimiters, while the existing one-level/capped repository summary remains in place.

## Security

Reviewed trust boundaries: CLI flags, layered TOML, environment-derived API keys,
prompt/config paths, repository names and README summary, explicit endpoints, provider
errors/responses, JSON deserialization, generated manifest paths/content, staged writes,
overwrite/rollback, symlinks, subprocess argument boundaries, raw-response persistence,
terminal output, and resource amplification.

Fixed: symlink redirection, wrong-type overwrite coercion, output/path controls,
unbounded provider-response/manifest work, unsafe raw-response persistence,
credential-bearing endpoint userinfo, raw provider error output, context line injection,
and ignored stage-write failures. Regression tests cover each practical boundary.

Remaining concern: filesystem checks and promotion cannot be fully race-free without
descriptor-relative filesystem primitives from the Kujo runtime. PackWrite rechecks the
location immediately before promotion, uses argument-vector subprocess calls, and never
executes model-generated commands; a hostile concurrent local process with write access
to the same repository remains outside the CLI's complete control.

## Compatibility

- Public APIs: no supported function signatures removed; new validation helpers/limits
  were added.
- CLI: commands and exit-code classes remain unchanged. Safety errors, provider failure
  wording, and raw-save warning/refusal behavior changed intentionally.
- File formats/schemas: JSON manifest and generated Markdown pack shapes unchanged.
- Config: no new keys or environment variables. Valid documented values are unchanged;
  invalid types/ranges now fail rather than coerce or crash.
- External consumers: normal consumers are unaffected. Automation that embedded
  credentials in endpoint URLs, reused raw-response filenames, traversed symlink output
  directories, or emitted oversized packs must migrate to the safe documented behavior.

## Cross-Repository Follow-Ups

### `kujolang/kujo`: trusted CI distribution contract (resolved)

- Dependency/contract: PackWrite CI requires a Kujo interpreter from a trustworthy,
  reproducible source.
- Resolution: Kujo v1.1.0 now publishes a Linux x64 release archive with SHA-256
  checksums. PackWrite pins both the release version and the verified archive digest in
  `.github/workflows/ci.yml`.
- Verification: CI downloads the exact archive, runs `sha256sum --check --strict`,
  extracts only after verification, confirms `kujo --version`, then runs the offline
  check and test gates.
- Update procedure: when upgrading Kujo, review the Kujo release, change both
  `KUJO_VERSION` and `KUJO_LINUX_X64_SHA256`, and rerun the workflow. Never advance the
  version without updating the pinned digest from the release's checksum asset.

## Remaining Work

- **P0:** none known.
- **P1:** none known; hosted CI now consumes a pinned, checksummed Kujo release.
- **P2:** none known. Machine-readable validation/doctor/summary output and age-gated
  crash-orphan cleanup were completed in the follow-up. One-pass validation reads remain
  unjustified without evidence of material I/O cost on real packs.
- **P3:** none known. Quiet scripting output and provider compatibility documentation
  were completed in the follow-up.
- **Evidence boundary, not an open defect:** live retries remain single-shot until the
  Kujo AI adapter exposes safe status classification; stricter endpoint path heuristics
  remain unjustified without a demonstrated compatibility or safety failure.
- **Not worth changing now:** caching repository context, adding concurrency, or
  replacing the zero-dependency implementation; current pack sizes and execution model
  do not justify their complexity.

## Verification Receipt

| Command | Result |
| --- | --- |
| `make check` | Passed |
| `make unit` | Passed initially: 168 assertions; follow-up: 182 assertions |
| `make integration` | Passed initially: 58 assertions; follow-up: 66 assertions |
| `make test` | Passed after follow-up: Kujo checks, Bash syntax, 182 unit + 66 CLI assertions |
| `make smoke` | Passed: version and help |
| `make scripts` | Passed |
| `bash -n bin/packwrite tests/run.sh tests/cli_integration.sh .github/scripts/check-kujo-tool-artifacts.sh` | Passed |
| `.github/scripts/check-kujo-tool-artifacts.sh HEAD^ HEAD` | Passed |
| Kujo v1.1.0 Linux x64 release archive SHA-256 | Passed; pinned digest matched and binary reported `kujo 1.1.0` in an Ubuntu 22.04 container |
| `./bin/packwrite --help` | Passed |
| `./bin/packwrite version` | Passed: `packwrite 1.0.0` |
| `git diff --check` | Passed |
| Large invalid-response offline probe | Failed safely in 2.17 s with a 1,128-byte receipt |

No live model call, secret, package publication, release tag, or sibling-repository
write was performed.
