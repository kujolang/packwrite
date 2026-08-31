# Hardening PackWrite

## Why we did it

PackWrite turns a large project prompt into a validated agent execution pack.
That puts model output, repository paths, configuration, and filesystem writes
on the same trust boundary. The v1.1.0 work focused on making that boundary
predictable: bounded parsing, explicit manifest limits, contained writes,
machine-readable output, stronger tests, and a release that works with the
standalone Kujo runtime.

## What changed

The parser now bounds diagnostic previews instead of processing an entire bad
response before reporting it. Manifest size, path, file-count, per-file, and
total-content limits are explicit. Output ancestors are checked for symlinks,
raw responses use private atomic writes and refuse overwrite, and configuration
types fail cleanly. Automation gained summary, JSON, quiet, and strict doctor
modes. The command module and parser became self-contained for released Kujo
runtimes.

## How we measured it

We compared the commit immediately before hardening (`f634251`) with the v1.1.0
release commit (`b696522`). Both ran the same offline fixtures on Kujo 1.1.0.
Hyperfine used three warmups and 10 measured runs per latency workload. Peak RSS
used 10 runs. Kujo Eval ran the same 11 deterministic checks against both
states. Raw evidence and reproduction scripts are committed with the report.

The unmodified baseline cannot start on standalone Kujo 1.1.0. We kept that as
a reliability result, then applied a documented parser/module compatibility
shim only to its disposable performance checkout so other timings remained
comparable.

## Before vs after

| Metric | Before | After | Change |
|---|---:|---:|---:|
| Kujo Eval | 4/11 | 11/11 | +7 checks |
| Invalid response, 64 KiB | ≥5.015 s timeout | 565.7 ms | ≥88.7% lower latency |
| Generate, 13 files | 1.010 s | 1.555 s | 54.0% slower |
| Generate, 64 files | 5.343 s | 8.331 s | 55.9% slower |
| Validate | 391.2 ms | 462.4 ms | 18.2% slower |
| Peak RSS, 13 files | 16.09 MB | 16.45 MB | 2.24% higher |
| Prompt bytes | 3,034 | 3,247 | 7.0% higher |
| Native clean test runs | 2/3 | 3/3 | +1 |

## Biggest improvements

The meaningful speedup is on the failure path. Across 10 runs, current rejected
a 64 KiB malformed response in a 565.7 ms median. Baseline hit the five-second
cap every time. Current also passed nested-output, typed-config, raw-evidence,
summary JSON, strict doctor, and symlink-containment checks that baseline failed.

The standalone compatibility fix matters even more plainly: current launches
on the released runtime; unmodified baseline does not.

## What surprised us

Hardening did not make normal work faster. The extra semantic and filesystem
checks add visible latency, especially as file count grows. The smallest invalid
input is also slightly slower. The optimization only becomes decisive when a
malformed response grows large enough to expose the old parser's scaling.

## What did not improve

Common successful CLI output stayed the same size. Prompt and context bytes
increased because the hardened prompt adds explicit untrusted-data boundaries.
Source, tests, and repository footprint increased. No live model was used, so
we cannot claim token or dollar savings.

## What remains

The next high-value task is profiling successful 13–64-file generation to keep
the safety properties while reducing repeated validation and containment work.
Token and agent-step claims need a provider-instrumented Eval. Small latency
deltas should also be repeated on an idle host because this evidence was
captured on a shared machine under realistic contention.

## Reproducing the results

Run the scripts documented in
[`benchmarks/hardening/README.md`](../README.md). Machine-readable results are
in [`evaluation-results.json`](../results/evaluation-results.json), with raw
Hyperfine, memory, test, and Kujo Eval evidence alongside them.
