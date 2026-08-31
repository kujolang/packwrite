# Kujo Eval criteria

The same 11 checks run against both repository states. A check earns one pass only when
the target exhibits the stated externally observable behavior. Eval's pass/fail result
is the score; no subjective points are added afterward.

The checks cover minimal startup, ordinary validation and offline generation, nested
output correctness, config typing, bounded failure behavior, response-size stress,
raw-evidence preservation, machine-readable agent surfaces, strict diagnostic semantics,
and symlink containment. The baseline is expected to fail checks for capabilities or
protections introduced by hardening. This is intentional: the suite measures the
current behavioral contract, while the performance benchmarks separately compare only
workloads that both versions complete successfully.

Run each target three times with a fixed seed to detect intermittent behavior. Report
both raw passes and pass rate; do not interpret the pass rate as a universal software
quality percentage.
