# PackWrite repeat audit — installation failure reporting

Date: 2026-10-13. Repository: `kujolang/packwrite`; starting branch: `main`;
starting SHA: `d635a723e57f4e2221dd96b6b370e16e14533290`.
Ending implementation SHA: `e555afba5837275110d1016f1252243724275e74`; the subsequent documentation commit contains
this report.

PackWrite compiles prompts and filtered repository context into validated execution
packs. This fresh pass reviewed the launcher and installation, configuration and
prompt input, provider/fake-response boundary, context filtering and size bounds,
manifest/path checks, staged promotion/recovery, on-disk validation, diagnostic
output, documentation, test harness and CI. Prior audit reports remain historical.
The runtime and POSIX filesystem utilities are the important dependencies; the
Kujo package manifest still declares no package dependencies. Live provider calls
and sibling repository modifications were outside this offline verification.

## Reproduced change

| Problem / evidence | Root cause / implementation | Files / regression proof | Compatibility |
| --- | --- | --- | --- |
| `make -s install PREFIX=<temporary-directory>/missing` returned 0 and printed `linked ...` and setup guidance although `ln` reported that the destination did not exist. | A semicolon-separated recipe returned the last successful `echo` status. Enable shell failure propagation before running the existing commands. | `Makefile`; four assertions in `tests/cli_integration.sh` check nonzero failure, absence of false success guidance, exact symlink target with a space-containing prefix, and installed launcher version equivalence. | Successful installation output, default prefix, existing destination prerequisite, symlink target, and launcher behavior are preserved. Only a failed installation's status and misleading success output change. |

README installation guidance now states the existing destination prerequisite and
prefix override; README, AGENTS and NEXT_STEPS assertion counts are updated.
The same reproducer now returns make exit 2 with the original filesystem error and
no success receipt. No production Kujo code was changed.

## Verification and scope

- Baseline `make test`: 248 unit + 88 CLI assertions passed, including Kujo checks
  and Bash syntax checks.
- Final `make test`: 248 unit + 92 CLI assertions passed.
- `make smoke`, `bash .github/scripts/check-kujo-tool-artifacts.sh`,
  `git diff --check`: passed.
- Reproducer: Python `tempfile.TemporaryDirectory`, then
  `subprocess.run(['make', '-s', 'install', 'PREFIX=' + temp + '/missing'],
  capture_output=True, text=True)`. Before/after receipts and suite logs live in
  `/tmp/packwrite-repeat-audit/`; the durable results are recorded above.
- Hosted candidate CI (Kujo 1.2.2) and artifact guard must pass before main advances.
  Exact final commit and hosted run IDs are stored in the Strata handoff.

No public API, PackWrite command output, configuration format/default, environment
variable, generated file format or schema changed. No external consumer migration
or cross-repository work is required. The installation failure status correction
allows scripts to detect failure reliably.

No runtime, memory, token or context efficiency gain is claimed: generation paths,
resource limits, prompt construction, output sizes and dependency surface are
unchanged. Existing context caps and manifest limits were reviewed, not rewritten.
No new security fix or concurrency guarantee is claimed; previous reports' hostile
filesystem/multiwriter race limitations still apply. No new reproducible P0/P1/P2
runtime regression was established in this pass. Speculative redesigns and cosmetic
cleanup were not worth changing without further evidence. No unresolved blocker
was introduced.
