# PackWrite v1.1.0 hardening evaluation

This package compares pre-hardening commit `f634251` with release commit
`b696522` (v1.1.0). It uses identical offline fixtures, Kujo 1.1.0, Kujo Eval,
Hyperfine, `/usr/bin/time`, and repeated native test runs.

## Reproduce

Requirements: macOS, Bash, Git, Ruby, `jq`, `hyperfine`, GNU `gtimeout`, the
PackWrite repository, sibling `../kujo` built at v1.1.0, and sibling `../eval`.

```bash
bash benchmarks/hardening/scripts/prepare_workloads.sh
bash benchmarks/hardening/scripts/run_eval.sh
bash benchmarks/hardening/scripts/run_benchmarks.sh
ruby benchmarks/hardening/scripts/code_metrics.rb \
  benchmarks/hardening/results/work/checkouts/baseline \
  > benchmarks/hardening/results/code-metrics-baseline.json
ruby benchmarks/hardening/scripts/code_metrics.rb \
  benchmarks/hardening/results/work/checkouts/current \
  > benchmarks/hardening/results/code-metrics-current.json
ruby benchmarks/hardening/scripts/summarize.rb
```

The scripts only delete and recreate
`benchmarks/hardening/results/work`. Raw retained evidence lives under
`benchmarks/hardening/results`; disposable checkouts and large fixtures are
ignored by Git.

## Fairness and boundary note

The unmodified baseline cannot start with the standalone Kujo 1.1.0 release
because its `src.cli` module collides with the runtime's built-in `cli` module.
That is retained as a reliability finding. Performance runs apply the explicit
[`baseline-compat.patch`](baseline-compat.patch) to the disposable baseline:
it renames the module and copies the same argument parser locally without
changing command semantics. Both variants then receive the same runtime,
workspaces, manifests, environment, warmups, and run counts.

The host was shared with unrelated build and benchmark jobs. Hyperfine retains
all samples and variance, but absolute latency should be reconfirmed on an idle
host before using small deltas as release gates.

## Outputs

- [`reports/technical-evaluation.md`](reports/technical-evaluation.md): full engineering evaluation
- [`reports/public-case-study.md`](reports/public-case-study.md): publication-ready technical case study
- [`results/evaluation-results.json`](results/evaluation-results.json): machine-readable synthesis
- [`eval.json`](eval.json): Kujo Eval suite
- [`results/hyperfine`](results/hyperfine): raw timing samples
- [`results/memory`](results/memory): raw peak-RSS samples
- [`results/tests`](results/tests): repeated test evidence
- [`results/eval-baseline-report.md`](results/eval-baseline-report.md) and [`results/eval-current-report.md`](results/eval-current-report.md): Eval evidence

