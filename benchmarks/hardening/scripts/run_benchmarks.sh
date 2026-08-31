#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RESULTS="$REPO_ROOT/benchmarks/hardening/results"
WORK="$RESULTS/work"
KUJO_BIN="${KUJO_BIN:-$REPO_ROOT/../kujo/target/release/kujo}"
mkdir -p "$RESULTS/hyperfine" "$RESULTS/samples" "$RESULTS/memory" "$RESULTS/tests"

bench_pair() {
  local name="$1" baseline_cmd="$2" current_cmd="$3"
  test -s "$RESULTS/hyperfine/$name.json" && return 0
  hyperfine --warmup 3 --runs 10 --export-json "$RESULTS/hyperfine/$name.json" \
    --command-name baseline "$baseline_cmd" --command-name current "$current_cmd"
}

bin_for() { printf '%s/checkouts/%s/bin/packwrite' "$WORK" "$1"; }
ws_for() { printf '%s/workspaces/%s' "$WORK" "$1"; }

baseline_bin="$(bin_for baseline)"
current_bin="$(bin_for current)"
baseline_ws="$(ws_for baseline)"
current_ws="$(ws_for current)"

bench_pair version \
  "KUJO='$KUJO_BIN' '$baseline_bin' version >/dev/null" \
  "KUJO='$KUJO_BIN' '$current_bin' version >/dev/null"
bench_pair validate \
  "cd '$baseline_ws' && KUJO='$KUJO_BIN' '$baseline_bin' validate >/dev/null" \
  "cd '$current_ws' && KUJO='$KUJO_BIN' '$current_bin' validate >/dev/null"
bench_pair init-13 \
  "cd '$baseline_ws' && PACKWRITE_FAKE_RESPONSE_FILE='$WORK/manifests/valid-13.json' KUJO='$KUJO_BIN' '$baseline_bin' init MEGA_PROMPT.md --dry-run --overwrite >/dev/null" \
  "cd '$current_ws' && PACKWRITE_FAKE_RESPONSE_FILE='$WORK/manifests/valid-13.json' KUJO='$KUJO_BIN' '$current_bin' init MEGA_PROMPT.md --dry-run --overwrite >/dev/null"

for size in 32 64; do
  bench_pair "init-$size" \
    "cd '$baseline_ws' && PACKWRITE_FAKE_RESPONSE_FILE='$WORK/manifests/valid-$size.json' KUJO='$KUJO_BIN' '$baseline_bin' init MEGA_PROMPT.md --dry-run --overwrite >/dev/null" \
    "cd '$current_ws' && PACKWRITE_FAKE_RESPONSE_FILE='$WORK/manifests/valid-$size.json' KUJO='$KUJO_BIN' '$current_bin' init MEGA_PROMPT.md --dry-run --overwrite >/dev/null"
done

# Failure scaling. These are expected nonzero exits; the 64 KiB baseline is
# censored at five seconds to keep the reproducible suite bounded.
for size in 1k 64k; do
  timeout=20
  test "$size" = 64k && timeout=5
  hyperfine --warmup 3 --runs 10 --ignore-failure --export-json "$RESULTS/hyperfine/invalid-$size.json" \
    --command-name baseline "cd '$baseline_ws' && gtimeout -k 1 $timeout env PACKWRITE_FAKE_RESPONSE_FILE='$WORK/failures/invalid-$size.txt' KUJO='$KUJO_BIN' '$baseline_bin' init MEGA_PROMPT.md --output agent --overwrite >/dev/null" \
    --command-name current "cd '$current_ws' && gtimeout -k 1 $timeout env PACKWRITE_FAKE_RESPONSE_FILE='$WORK/failures/invalid-$size.txt' KUJO='$KUJO_BIN' '$current_bin' init MEGA_PROMPT.md --output agent --overwrite >/dev/null"
done

for variant in baseline current; do
  bin="$(bin_for "$variant")"
  ws="$(ws_for "$variant")"
  for workload in version validate init-13 invalid-1k invalid-64k; do
    out="$RESULTS/samples/$variant-$workload.out"
    set +e
    case "$workload" in
      version) KUJO="$KUJO_BIN" "$bin" version > "$out" 2>&1 ;;
      validate) (cd "$ws" && KUJO="$KUJO_BIN" "$bin" validate) > "$out" 2>&1 ;;
      init-13) (cd "$ws" && PACKWRITE_FAKE_RESPONSE_FILE="$WORK/manifests/valid-13.json" KUJO="$KUJO_BIN" "$bin" init MEGA_PROMPT.md --dry-run --overwrite) > "$out" 2>&1 ;;
      invalid-1k) (cd "$ws" && PACKWRITE_FAKE_RESPONSE_FILE="$WORK/failures/invalid-1k.txt" KUJO="$KUJO_BIN" "$bin" init MEGA_PROMPT.md --output agent --overwrite) > "$out" 2>&1 ;;
      invalid-64k) (cd "$ws" && gtimeout -k 1 5 env PACKWRITE_FAKE_RESPONSE_FILE="$WORK/failures/invalid-64k.txt" KUJO="$KUJO_BIN" "$bin" init MEGA_PROMPT.md --output agent --overwrite) > "$out" 2>&1 ;;
    esac
    code=$?
    set -e
    jq -n --arg variant "$variant" --arg workload "$workload" --argjson exit_code "$code" \
      --argjson bytes "$(wc -c < "$out" | tr -d ' ')" --argjson lines "$(wc -l < "$out" | tr -d ' ')" \
      '{variant:$variant,workload:$workload,exit_code:$exit_code,bytes:$bytes,lines:$lines}' \
      > "$RESULTS/samples/$variant-$workload.json"
  done

  (cd "$WORK/checkouts/$variant" && "$KUJO_BIN" run benchmark_prompt_probe.kujo -- "$ws") \
    > "$RESULTS/samples/$variant-prompt.json"

  for run in $(seq 1 10); do
    (cd "$ws" && /usr/bin/time -l env PACKWRITE_FAKE_RESPONSE_FILE="$WORK/manifests/valid-13.json" KUJO="$KUJO_BIN" \
      "$bin" init MEGA_PROMPT.md --dry-run --overwrite >/dev/null) \
      2> "$RESULTS/memory/$variant-init-13-$run.txt"
  done
done

for variant in baseline current; do
  checkout="$WORK/checkouts/$variant"
  for run in 1 2 3; do
    set +e
    (cd "$checkout" && /usr/bin/time -p env KUJO="$KUJO_BIN" bash tests/run.sh) \
      > "$RESULTS/tests/$variant-$run.out" 2> "$RESULTS/tests/$variant-$run.time"
    code=$?
    set -e
    printf '%s\n' "$code" > "$RESULTS/tests/$variant-$run.exit"
  done
done

printf 'benchmarks complete with %s\n' "$($KUJO_BIN --version)"
