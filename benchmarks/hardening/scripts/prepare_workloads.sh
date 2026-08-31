#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONFIG="$REPO_ROOT/benchmarks/hardening/benchmark-config.json"
WORK_ROOT="$REPO_ROOT/benchmarks/hardening/results/work"
KUJO_BIN="${KUJO_BIN:-$REPO_ROOT/../kujo/target/release/kujo}"

case "$WORK_ROOT" in
  "$REPO_ROOT"/benchmarks/hardening/results/work) ;;
  *) echo "refusing unexpected work root: $WORK_ROOT" >&2; exit 2 ;;
esac

rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT/checkouts/baseline" "$WORK_ROOT/checkouts/current"
mkdir -p "$WORK_ROOT/workspaces/baseline" "$WORK_ROOT/workspaces/current"
mkdir -p "$WORK_ROOT/manifests" "$WORK_ROOT/failures"
cp "$REPO_ROOT/benchmarks/hardening/scripts/eval_case.sh" "$WORK_ROOT/eval-case.sh"

baseline_sha="$(jq -r .baseline_sha "$CONFIG")"
current_sha="$(jq -r .current_sha "$CONFIG")"
git -C "$REPO_ROOT" archive "$baseline_sha" | tar -x -C "$WORK_ROOT/checkouts/baseline"
git -C "$REPO_ROOT" archive "$current_sha" | tar -x -C "$WORK_ROOT/checkouts/current"

# The unmodified baseline cannot start on the fixed standalone Kujo runtime
# because src.cli collides with the runtime's built-in cli module. Preserve that
# as a reliability result, then apply the v1.1.0 compatibility shim to the
# disposable baseline checkout so the remaining workloads are comparable.
git -C "$REPO_ROOT" apply --directory=benchmarks/hardening/results/work/checkouts/baseline \
  "$REPO_ROOT/benchmarks/hardening/baseline-compat.patch"

for variant in baseline current; do
  cp "$REPO_ROOT/benchmarks/hardening/scripts/prompt_probe.kujo" "$WORK_ROOT/checkouts/$variant/benchmark_prompt_probe.kujo"
  cp -R "$WORK_ROOT/checkouts/current/tests/fixtures/golden-agent" "$WORK_ROOT/workspaces/$variant/agent"
  printf '# Benchmark project\n\nBuild a deterministic local demonstration.\n' > "$WORK_ROOT/workspaces/$variant/MEGA_PROMPT.md"
  printf '[output]\noverwrite = "false"\n' > "$WORK_ROOT/workspaces/$variant/bad-config.toml"
done

"$KUJO_BIN" run "$WORK_ROOT/checkouts/current/tests/fixture.kujo" > "$WORK_ROOT/manifests/valid-13.json"
sed 's#agent/#build/agent/#g' "$WORK_ROOT/manifests/valid-13.json" > "$WORK_ROOT/manifests/nested.json"

ruby -rjson -e '
  source = JSON.parse(File.read(ARGV.shift))
  out_dir = ARGV.shift
  [32, 64].each do |target|
    data = Marshal.load(Marshal.dump(source))
    extra = target - data.fetch("files").length
    extra.times do |i|
      data["files"] << {"path" => format("agent/notes/extra-%03d.md", i), "content" => "# Extra #{i}\n\nDeterministic benchmark content.\n"}
    end
    File.write(File.join(out_dir, "valid-#{target}.json"), JSON.generate(data))
  end
' "$WORK_ROOT/manifests/valid-13.json" "$WORK_ROOT/manifests"

ruby -e '
  out = ARGV.shift
  {1024 => "1k", 65536 => "64k", 262144 => "256k", 1048576 => "1m", 1620000 => "1620k", 18874368 => "18m"}.each do |size, label|
    File.binwrite(File.join(out, "invalid-#{label}.txt"), "x" * size)
  end
' "$WORK_ROOT/failures"

printf 'prepared baseline=%s current=%s kujo=%s\n' "$baseline_sha" "$current_sha" "$("$KUJO_BIN" --version)"
