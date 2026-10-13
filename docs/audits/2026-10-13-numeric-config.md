# PackWrite independent pass — non-finite configuration

Date: 2026-10-13. Repository: `kujolang/packwrite`; starting branch: `main`;
starting SHA: `1504c58ccf7bb8fb05910b59e07f826104cbb64f`.
Ending implementation SHA: `6cc731f818a9227394c471fb0b2eac882ee49d92`; the
subsequent documentation commit contains this report.

Reviewed configuration parsing/layering and validation, numeric CLI parsing,
config/summary JSON error paths, manifest parsing/diagnostics and current tests.
This pass extends the earlier broad audits; their measurements remain historical
rather than being presented as new results.

## Reproduced issue and correction

| Evidence | Root cause and fix | Proof / compatibility |
| --- | --- | --- |
| TOML `[model] temperature = nan`, `timeout = nan`, or `timeout = inf` passed validation; `packwrite config --config bad.toml` printed a heading, then crashed with exit 4 and `Cannot convert non-finite float ... to JSON`. | Type checks accepted every float, while NaN bypassed range comparisons and positive infinity passed the timeout lower bound. A private finite-number predicate now guards both values before serialization or provider dispatch. | The same three CLI cases now return exit 1, the existing configuration-error wording, and empty stderr. Six layered-config assertions reject NaN/positive infinity/negative infinity for both fields; one preserves zero temperature and a large finite timeout. Three CLI assertions prevent traceback regressions. |

The guard accepts all integers and finite floats before applying the existing
ranges. For floats, self-subtraction equals zero only when finite; this avoids a
new runtime builtin dependency or an arbitrary upper limit on timeouts. No provider
request was made. Large finite timeout acceptance refers to config validation,
not certification of a live provider/runtime's duration range.

Public signatures, valid CLI output, error wording, generated pack formats, config
keys/defaults, environment variables and JSON schemas are unchanged. TOML's special
float values remain parseable, but are rejected as invalid model configuration.
No sibling repository or external consumer migration is required.

## Verification

- Baseline `make test`: 241 unit + 85 CLI assertions passed, including Kujo checks
  and Bash syntax validation.
- Final `make test`: 248 unit + 88 CLI assertions passed.
- `make smoke`, `bash .github/scripts/check-kujo-tool-artifacts.sh`, and
  `git diff --check`: passed.
- Offline CLI reproducer: write `[model]` followed by one offending assignment to
  `bad.toml`, then run `bin/packwrite config --config bad.toml` in that directory.
  Before/after receipts are in `/tmp/packwrite-oct13-review/numeric/`; the observed
  errors and exit codes are preserved above because temporary logs may expire.
- Hosted CI on pinned Kujo 1.2.2 and artifact guard must pass for the candidate SHA
  before main advances. Exact run IDs and final SHA are recorded in Strata.

Only the config numeric predicate and regression coverage changed in code. No
performance/token/memory improvement is claimed, and no dependency or network
surface was added. Previous concurrency boundaries remain unchanged. No new
unresolved blocker or cross-repository requirement was established in this pass.
