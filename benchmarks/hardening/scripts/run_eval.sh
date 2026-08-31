#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EVAL_ROOT="${EVAL_ROOT:-$REPO_ROOT/../eval}"
KUJO_BIN="${KUJO_BIN:-$REPO_ROOT/../kujo/target/release/kujo}"
EVAL_KUJO="${EVAL_KUJO:-$REPO_ROOT/../kujo/target/release/kujo}"
RESULTS="$REPO_ROOT/benchmarks/hardening/results"
CASE_RUNNER="$REPO_ROOT/.pw-case.sh"

cleanup() {
  rm -f "$CASE_RUNNER" "$REPO_ROOT/.pw-suite-baseline.json" "$REPO_ROOT/.pw-suite-current.json"
}
trap cleanup EXIT
cp "$REPO_ROOT/benchmarks/hardening/scripts/eval_case.sh" "$CASE_RUNNER"

for variant in baseline current; do
  RUNTIME_SUITE="$REPO_ROOT/.pw-suite-$variant.json"
  jq --arg runner "$CASE_RUNNER" --arg root "$REPO_ROOT" --arg variant "$variant" --arg kujo "$KUJO_BIN" \
    'walk(if type == "string" then gsub("__PW_CASE__"; $runner) | gsub("__PW_ROOT__"; $root) | gsub("__PW_VARIANT__"; $variant) | gsub("__PW_KUJO__"; $kujo) else . end)' \
    "$REPO_ROOT/benchmarks/hardening/eval.json" > "$RUNTIME_SUITE"
  rm -rf "$RESULTS/eval-$variant" "$RESULTS/eval-evidence/$variant"
  (cd "$EVAL_ROOT" && "$EVAL_KUJO" run main.kujo run "$RUNTIME_SUITE" \
      --output-dir "$RESULTS/eval-$variant" --summary-channel-path "$RESULTS/eval-$variant/cli-summary.json" \
      --repeat 3 --seed 20260830 --artifact-checksums --json \
      > "$RESULTS/eval-$variant.stdout.json" || true)
  (cd "$EVAL_ROOT" && "$EVAL_KUJO" run main.kujo report "$RUNTIME_SUITE" \
    --output-dir "$RESULTS/eval-$variant" --format md > "$RESULTS/eval-$variant-report.md")
  (cd "$EVAL_ROOT" && "$EVAL_KUJO" run main.kujo verify-manifest --output-dir "$RESULTS/eval-$variant" --json \
    > "$RESULTS/eval-$variant-manifest-verification.json") || true
done

(cd "$EVAL_ROOT" && "$EVAL_KUJO" run main.kujo compare "$RESULTS/eval-baseline/last_run.json" "$RESULTS/eval-current/last_run.json" \
  > "$RESULTS/eval-comparison.md") || true
