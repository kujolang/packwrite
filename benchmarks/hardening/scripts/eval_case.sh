#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${PW_R:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
WORK_ROOT="$REPO_ROOT/benchmarks/hardening/results/work"
VARIANT="${PW_V:-${BENCH_VARIANT:-}}"
test -n "$VARIANT" || { echo "set PW_V to baseline or current" >&2; exit 2; }
KUJO_BIN="${PW_K:-${KUJO_BIN:-$REPO_ROOT/../kujo/target/release/kujo}}"
TARGET="$WORK_ROOT/checkouts/$VARIANT"
WS="$WORK_ROOT/workspaces/$VARIANT"
BIN="$TARGET/bin/packwrite"
CASE="${1:?case required}"
EVIDENCE="$REPO_ROOT/benchmarks/hardening/results/eval-evidence/$VARIANT"
mkdir -p "$EVIDENCE"

run_capture() {
  local name="$1"
  shift
  set +e
  "$@" > "$EVIDENCE/$name.out" 2>&1
  local code=$?
  set -e
  printf '%s' "$code" > "$EVIDENCE/$name.exit"
  return "$code"
}

run_in_workspace_capture() {
  local name="$1"
  shift
  set +e
  (cd "$WS" && "$@") > "$EVIDENCE/$name.out" 2>&1
  local code=$?
  set -e
  printf '%s' "$code" > "$EVIDENCE/$name.exit"
  return "$code"
}

case "$CASE" in
  version)
    output="$(KUJO="$KUJO_BIN" "$BIN" version)"
    grep -q '^packwrite ' <<< "$output"
    ;;
  validate)
    output="$(cd "$WS" && KUJO="$KUJO_BIN" "$BIN" validate)"
    grep -q 'Validation passed' <<< "$output"
    ;;
  init-dry)
    output="$(cd "$WS" && PACKWRITE_FAKE_RESPONSE_FILE="$WORK_ROOT/manifests/valid-13.json" KUJO="$KUJO_BIN" "$BIN" init MEGA_PROMPT.md --dry-run --overwrite)"
    grep -q 'Dry run complete' <<< "$output"
    ;;
  nested-output)
    rm -rf "$WS/build"
    if ! (cd "$WS" && PACKWRITE_FAKE_RESPONSE_FILE="$WORK_ROOT/manifests/nested.json" KUJO="$KUJO_BIN" "$BIN" init MEGA_PROMPT.md --output build/agent > "$EVIDENCE/nested-output.out" 2>&1); then
      exit 1
    fi
    test -f "$WS/build/agent/MASTER.md"
    ;;
  config-type)
    if run_in_workspace_capture config-type env KUJO="$KUJO_BIN" "$BIN" config --config "$WS/bad-config.toml"; then
      exit 1
    fi
    grep -q 'Invalid configuration' "$EVIDENCE/config-type.out"
    ;;
  invalid-large)
    if run_in_workspace_capture invalid-large gtimeout -k 2 15 env PACKWRITE_FAKE_RESPONSE_FILE="$WORK_ROOT/failures/invalid-64k.txt" KUJO="$KUJO_BIN" "$BIN" init MEGA_PROMPT.md --output agent --overwrite; then
      exit 1
    fi
    test "$(cat "$EVIDENCE/invalid-large.exit")" = "1"
    test "$(wc -c < "$EVIDENCE/invalid-large.out" | tr -d ' ')" -le 2048
    grep -q 'could not be parsed into files' "$EVIDENCE/invalid-large.out"
    ;;
  oversized)
    if run_in_workspace_capture oversized gtimeout -k 2 5 env PACKWRITE_FAKE_RESPONSE_FILE="$WORK_ROOT/failures/invalid-18m.txt" KUJO="$KUJO_BIN" "$BIN" init MEGA_PROMPT.md --output agent --overwrite; then
      exit 1
    fi
    test "$(cat "$EVIDENCE/oversized.exit")" != "124"
    test "$(wc -c < "$EVIDENCE/oversized.out" | tr -d ' ')" -le 2048
    grep -Eq 'safety limit|exceeds maximum read size' "$EVIDENCE/oversized.out"
    ;;
  raw-no-overwrite)
    raw="$WS/existing-raw.txt"
    printf 'preserve-me\n' > "$raw"
    before="$(cksum "$raw")"
    if run_in_workspace_capture raw-no-overwrite env PACKWRITE_FAKE_RESPONSE_FILE="$WORK_ROOT/manifests/valid-13.json" KUJO="$KUJO_BIN" "$BIN" init MEGA_PROMPT.md --output agent --overwrite --save-raw-response "$raw"; then
      exit 1
    fi
    after="$(cksum "$raw")"
    test "$before" = "$after"
    grep -q 'refusing to overwrite' "$EVIDENCE/raw-no-overwrite.out"
    ;;
  summary-json)
    (cd "$WS" && KUJO="$KUJO_BIN" "$BIN" summary --json) > "$EVIDENCE/summary-json.out"
    jq -e '.ok == true and .phase_count == 6' "$EVIDENCE/summary-json.out" >/dev/null
    ;;
  doctor-json)
    if run_in_workspace_capture doctor-json env KUJO="$KUJO_BIN" "$BIN" doctor --provider anthropic --strict --json; then
      exit 1
    fi
    test "$(cat "$EVIDENCE/doctor-json.exit")" = "1"
    jq -e '.ok == false and (.blockers | length) > 0' "$EVIDENCE/doctor-json.out" >/dev/null
    ;;
  symlink-output)
    rm -rf "$WS/link-parent" "$WS/outside"
    mkdir -p "$WS/outside"
    ln -s "$WS/outside" "$WS/link-parent"
    if run_in_workspace_capture symlink-output env PACKWRITE_FAKE_RESPONSE_FILE="$WORK_ROOT/manifests/valid-13.json" KUJO="$KUJO_BIN" "$BIN" init MEGA_PROMPT.md --output link-parent/agent; then
      exit 1
    fi
    test ! -e "$WS/outside/agent"
    grep -q 'symlink component' "$EVIDENCE/symlink-output.out"
    ;;
  *)
    echo "unknown eval case: $CASE" >&2
    exit 2
    ;;
esac
