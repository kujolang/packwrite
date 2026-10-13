#!/usr/bin/env bash
# PackWrite CLI integration test.
#
# Drives the real `packwrite` binary end-to-end in a throwaway directory, using
# the PACKWRITE_FAKE_RESPONSE_FILE seam so no network/API key is needed.
#
#   ./tests/cli_integration.sh
#   KUJO=/path/to/kujo/target/release/kujo ./tests/cli_integration.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUJO="${KUJO:-kujo}"
BIN="$PROJECT_DIR/bin/packwrite"

pass=0
fail=0
ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); echo "  FAIL: $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Generate a valid fake model response.
"$KUJO" run "$PROJECT_DIR/tests/fixture.kujo" > "$TMP/fake.json"
export PACKWRITE_FAKE_RESPONSE_FILE="$TMP/fake.json"

cd "$TMP"
printf '# Demo\n\nBuild a demo.\n' > MEGA_PROMPT.md

# --- quiet mode suppresses successful init output without hiding failures ---
quiet_out="$(KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --quiet 2>&1)"
if [ -z "$quiet_out" ]; then ok; else bad "--quiet emitted successful init output"; fi
if [ -f "$TMP/agent/MASTER.md" ]; then ok; else bad "--quiet init did not generate the pack"; fi
rm -rf "$TMP/agent"
quiet_error="$(KUJO="$KUJO" "$BIN" init DOES-NOT-EXIST.md --quiet 2>&1 || true)"
if echo "$quiet_error" | grep -q '^error:'; then ok; else bad "--quiet hid an init failure"; fi

# --- dry run writes nothing ---
dry_out="$(KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --dry-run 2>&1)"
if echo "$dry_out" | grep -q "\[1/8\]"; then ok; else bad "init did not print progress steps"; fi
if echo "$dry_out" | grep -q "Dry run complete"; then ok; else bad "dry run progress completion missing"; fi
if [ -d "$TMP/agent" ]; then bad "dry-run created agent dir"; else ok; fi

# --- real init succeeds and writes the pack ---
if KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md >/dev/null; then ok; else bad "init exit non-zero"; fi
for f in MASTER.md TODO.md HANDOFF.md DECISIONS.md REVIEW_CHECKLIST.md DEEPSEEK_START.md CODEX_REVIEW_PROMPT.md; do
  if [ -f "$TMP/agent/$f" ]; then ok; else bad "missing agent/$f"; fi
done
if [ -f "$TMP/agent/phases/01-alpha.md" ]; then ok; else bad "missing phase file"; fi

# --- fenced JSON also parses ---
printf '```json\n' > "$TMP/fake-fenced.json"
cat "$TMP/fake.json" >> "$TMP/fake-fenced.json"
printf '\n```\n' >> "$TMP/fake-fenced.json"
rm -rf "$TMP/agent"
export PACKWRITE_FAKE_RESPONSE_FILE="$TMP/fake-fenced.json"
if KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md >/dev/null; then ok; else bad "init failed for fenced JSON"; fi
if [ -f "$TMP/agent/MASTER.md" ]; then ok; else bad "fenced JSON run did not write agent/MASTER.md"; fi
export PACKWRITE_FAKE_RESPONSE_FILE="$TMP/fake.json"

# --- overwrite protection ---
if KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md >/dev/null 2>&1; then
  bad "init overwrote without --overwrite"
else
  ok
fi
# --- explicit overwrite allowed ---
if KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --overwrite >/dev/null; then ok; else bad "--overwrite failed"; fi

# --- overwrite is a clean replace: orphan files are pruned ---
echo "stale" > "$TMP/agent/phases/99-orphan.md"
echo "stale" > "$TMP/agent/STALE_ROOT.md"
out="$(KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --overwrite 2>&1)"; code=$?
if [ "$code" -eq 0 ]; then ok; else bad "init --overwrite crashed (exit $code): $out"; fi
if [ ! -f "$TMP/agent/phases/99-orphan.md" ] && [ ! -f "$TMP/agent/STALE_ROOT.md" ]; then ok; else bad "orphan files survived --overwrite"; fi
if echo "$out" | grep -q "Pruned:"; then ok; else bad "init summary did not report pruned files"; fi
if [ -f "$TMP/agent/MASTER.md" ]; then ok; else bad "legit file missing after prune"; fi

# --- nested output dirs stage and promote as siblings of the final directory ---
sed 's#agent/#build/agent/#g' "$TMP/fake.json" > "$TMP/fake-nested.json"
rm -rf "$TMP/agent" "$TMP/build"
export PACKWRITE_FAKE_RESPONSE_FILE="$TMP/fake-nested.json"
if KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --output build/agent >/dev/null; then ok; else bad "nested output init failed"; fi
if [ -f "$TMP/build/agent/MASTER.md" ]; then ok; else bad "nested output missing MASTER.md"; fi
echo "stale" > "$TMP/build/agent/STALE.md"
if KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --output build/agent --overwrite >/dev/null; then ok; else bad "nested output overwrite failed"; fi
if [ ! -f "$TMP/build/agent/STALE.md" ]; then ok; else bad "nested output overwrite left stale file"; fi
rm -rf "$TMP/build"
export PACKWRITE_FAKE_RESPONSE_FILE="$TMP/fake.json"

# --- output symlink ancestors are rejected before generation ---
mkdir "$TMP/outside"
ln -s "$TMP/outside" "$TMP/build"
out="$(KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --output build/agent 2>&1 || true)"
if echo "$out" | grep -q "symlink component"; then ok; else bad "symlink output ancestor was not rejected"; fi
if [ ! -e "$TMP/outside/agent" ]; then ok; else bad "symlink output ancestor redirected a write outside the project"; fi
rm "$TMP/build"

# --- raw responses are private, atomic, and never overwrite existing files ---
rm -rf "$TMP/agent" "$TMP/raw-response.txt"
if KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --save-raw-response raw-response.txt >/dev/null; then ok; else bad "raw response save failed"; fi
if [ -f "$TMP/raw-response.txt" ]; then ok; else bad "raw response file missing"; fi
case "$(ls -l "$TMP/raw-response.txt")" in
  -rw-------*) ok ;;
  *) bad "raw response file is not owner-only" ;;
esac
raw_before="$(cksum "$TMP/raw-response.txt")"
rm -rf "$TMP/agent"
out="$(KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --save-raw-response raw-response.txt 2>&1 || true)"
raw_after="$(cksum "$TMP/raw-response.txt")"
if echo "$out" | grep -q "refusing to overwrite"; then ok; else bad "raw response overwrite was not refused"; fi
if [ "$raw_before" = "$raw_after" ]; then ok; else bad "existing raw response file changed"; fi
rm -f "$TMP/raw-response.txt"

# --- validate passes ---
if KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md >/dev/null && KUJO="$KUJO" "$BIN" validate >/dev/null; then ok; else bad "validate failed on good pack"; fi

# --- JSON validation and summary are single machine-readable objects ---
validate_json="$(KUJO="$KUJO" "$BIN" validate --json)"
if [[ "$validate_json" == \{*\} ]] && echo "$validate_json" | grep -q '"ok":true' && echo "$validate_json" | grep -q '"errors":\[\]'; then ok; else bad "validate --json contract failed"; fi
summary_json="$(KUJO="$KUJO" "$BIN" summary --json)"
if [[ "$summary_json" == \{*\} ]] && echo "$summary_json" | grep -q '"ok":true' && echo "$summary_json" | grep -q '"phase_count":6' && echo "$summary_json" | grep -q '"next_command":"packwrite prompt deepseek"'; then ok; else bad "summary --json contract failed"; fi
summary_out="$(KUJO="$KUJO" "$BIN" summary)"
if echo "$summary_out" | grep -q "PackWrite pack summary"; then ok; else bad "summary human output missing heading"; fi

# --- prompt commands ---
if prompt_out="$(KUJO="$KUJO" "$BIN" prompt deepseek)" && [[ "$prompt_out" == *"autonomous"* ]]; then ok; else bad "prompt deepseek missing content"; fi
if prompt_out="$(KUJO="$KUJO" "$BIN" prompt codex-review)" && [[ "$prompt_out" == *"repair checklist"* ]]; then ok; else bad "prompt codex-review missing content"; fi

# --- prompt fallback when file absent ---
rm -rf "$TMP/agent"
if prompt_out="$(KUJO="$KUJO" "$BIN" prompt deepseek)" && [[ "$prompt_out" == *"autonomous"* ]]; then ok; else bad "prompt deepseek fallback missing"; fi

# --- missing prompt error ---
rm -f "$TMP/MEGA_PROMPT.md"
if KUJO="$KUJO" "$BIN" init NOPE.md >/dev/null 2>&1; then
  bad "init succeeded with missing prompt"
else
  ok
fi
printf '# Demo\n\nBuild a demo.\n' > MEGA_PROMPT.md

# --- invalid JSON gives diagnostics and leaves no partial output ---
printf 'not-json\n' > "$TMP/fake-bad.json"
rm -rf "$TMP/agent"
export PACKWRITE_FAKE_RESPONSE_FILE="$TMP/fake-bad.json"
out="$(KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md 2>&1 || true)"
if echo "$out" | grep -q "could not be parsed into files"; then ok; else bad "invalid JSON did not return parse error"; fi
if echo "$out" | grep -q "provider="; then ok; else bad "invalid JSON diagnostics missing provider"; fi
if [ ! -d "$TMP/agent" ]; then ok; else bad "invalid JSON created a partial agent dir"; fi
export PACKWRITE_FAKE_RESPONSE_FILE="$TMP/fake.json"

# --- deferred commands report planned-not-implemented (exit 2) ---
for c in compare repair-pack; do
  out="$(KUJO="$KUJO" "$BIN" "$c" 2>&1 || true)"
  if echo "$out" | grep -q "planned for a future version"; then ok; else bad "$c missing planned message"; fi
done

# --- anthropic without endpoint fails with an OpenAI-compatible explanation ---
printf '# Demo\n' > MEGA_PROMPT.md
unset PACKWRITE_FAKE_RESPONSE_FILE
out="$(KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --provider anthropic 2>&1 || true)"
if echo "$out" | grep -q "OpenAI-compatible"; then ok; else bad "anthropic error missing OpenAI-compatible note"; fi
export PACKWRITE_FAKE_RESPONSE_FILE="$TMP/fake.json"

# --- malformed numeric flags yield a clean error, not a VM crash ---
out="$(KUJO="$KUJO" "$BIN" config --temperature abc 2>&1 || true)"
if echo "$out" | grep -q "Invalid --temperature"; then ok; else bad "malformed --temperature not reported cleanly"; fi
if echo "$out" | grep -qi "Runtime Error"; then bad "malformed --temperature crashed the VM"; else ok; fi
out="$(KUJO="$KUJO" "$BIN" config --timeout nope 2>&1 || true)"
if echo "$out" | grep -q "Invalid --timeout"; then ok; else bad "malformed --timeout not reported cleanly"; fi
# out-of-range temperature is rejected too
out="$(KUJO="$KUJO" "$BIN" config --temperature 9 2>&1 || true)"
if echo "$out" | grep -q "between 0.0 and 2.0"; then ok; else bad "out-of-range --temperature not reported"; fi

# --- doctor --strict exits non-zero on a blocking issue; plain doctor exits 0 ---
# anthropic has no native endpoint preset, so the endpoint is always unresolved here.
if KUJO="$KUJO" "$BIN" doctor --provider anthropic >/dev/null 2>&1; then ok; else bad "plain doctor should exit 0"; fi
if KUJO="$KUJO" "$BIN" doctor --provider anthropic --strict >/dev/null 2>&1; then
  bad "doctor --strict should fail when the endpoint is unresolved"
else
  ok
fi
strict_out="$(KUJO="$KUJO" "$BIN" doctor --provider anthropic --strict 2>&1 || true)"
if echo "$strict_out" | grep -q "blocking issue"; then ok; else bad "doctor --strict did not report blocking issues"; fi
doctor_json="$(KUJO="$KUJO" "$BIN" doctor --provider anthropic --json)"
if [[ "$doctor_json" == \{*\} ]] && echo "$doctor_json" | grep -q '"ok":false' && echo "$doctor_json" | grep -q '"blockers":\['; then ok; else bad "doctor --json contract failed"; fi
if KUJO="$KUJO" "$BIN" doctor --provider anthropic --strict --json >/dev/null 2>&1; then
  bad "doctor --strict --json should preserve strict exit behavior"
else
  ok
fi

# --- every subcommand honors --help (exit 0 + usage, no side effects) ---
for sub in "init" "validate" "summary" "prompt" "config" "doctor"; do
  out="$(KUJO="$KUJO" "$BIN" $sub --help 2>&1)"; code=$?
  if [ "$code" -eq 0 ] && echo "$out" | grep -qi "usage"; then ok; else bad "$sub --help did not show usage with exit 0"; fi
done
# prompt deepseek --help must show help, NOT emit the prompt
out="$(KUJO="$KUJO" "$BIN" prompt deepseek --help 2>&1)"
if echo "$out" | grep -qi "usage: packwrite prompt"; then ok; else bad "prompt deepseek --help emitted prompt instead of help"; fi

# Static help output is an agent-facing contract, so keep the full text exact.
emdash="$(printf '\342\200\224')"
help_expected="$(cat <<EOF
packwrite 1.1.0 $emdash compile a mega prompt into a validated /agent pack

Usage: packwrite <command> [arguments]

Commands:
  init [file]   Generate an /agent pack from a mega prompt
  validate      Validate an existing /agent pack
  summary       Summarize an existing /agent pack
  prompt <t>    Print a pack prompt (t = deepseek | codex-review)
  config        Show the resolved configuration
  doctor        Check config, provider, endpoint, and prompt/output state
  help          Show this help
  version       Show version

Config resolution: CLI flags > packwrite.toml > global config > defaults
API keys come from the environment (PACKWRITE_API_KEY or a provider key).
EOF
)"
out="$(KUJO="$KUJO" "$BIN" help 2>&1)"
if [ "$out" = "$help_expected" ]; then ok; else bad "main help output changed"; fi

init_help_expected="$(cat <<'EOF'
usage: packwrite init [mega-prompt-file] [options]

Options:
  --provider <name>     deepseek | openai | local (OpenAI-compatible)
                        other providers: set --endpoint to a compatible gateway
  --model <name>        model identifier
  --endpoint <url>      OpenAI-compatible chat-completions URL (overrides preset)
  --temperature <n>     sampling temperature
  --timeout <seconds>   request timeout
  --output <dir>        output pack directory (default: agent)
  --overwrite           replace an existing pack directory
  --dry-run             parse + plan but write nothing
  --config <file>       use a specific packwrite.toml
  --verbose             extra diagnostics (printed to stdout)
  --quiet               suppress successful progress and summary output
  --debug               sanitized provider/response diagnostics
  --save-raw-response <file>  save raw model response (may contain sensitive data)
EOF
)"
out="$(KUJO="$KUJO" "$BIN" init --help 2>&1)"
if [ "$out" = "$init_help_expected" ]; then ok; else bad "init help output changed"; fi

echo ""
# Every shell input must be parsed, including files after the first argument.
printf 'if then\n' > "$TMP/invalid.sh"
if make -s -C "$PROJECT_DIR" scripts SHELL_FILES="bin/packwrite $TMP/invalid.sh" >/dev/null 2>&1; then
  bad "shell syntax gate ignored a malformed second script"
else
  ok
fi

# An explicit offline fixture must fail closed, even when an inline fake exists.
for fixture_kind in missing directory invalid-utf8; do
  fixture_path="$TMP/fixture-$fixture_kind"
  case "$fixture_kind" in
    directory) mkdir "$fixture_path" ;;
    invalid-utf8) printf '\377' > "$fixture_path" ;;
  esac
  set +e
  out="$(PACKWRITE_FAKE_RESPONSE_FILE="$fixture_path" PACKWRITE_FAKE_RESPONSE='{}' KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --overwrite --quiet --provider unsupported-audit-provider 2>&1)"
  code=$?
  set -e
  if [ "$code" -eq 1 ] && [[ "$out" == error:*'Could not read fake response file:'* ]]; then
    ok
  else
    bad "invalid offline fixture $fixture_kind fell through or crashed: $out"
  fi
done

# Saved prompt failures are operational errors; absent prompts retain their fallback.
mkdir "$TMP/prompt-boundaries"
mkdir "$TMP/prompt-boundaries/agent"
printf '\377' > "$TMP/prompt-boundaries/agent/DEEPSEEK_START.md"
set +e
out="$(cd "$TMP/prompt-boundaries" && KUJO="$KUJO" "$BIN" prompt deepseek 2>&1)"
code=$?
set -e
if [ "$code" -eq 1 ] && [[ "$out" == error:* ]]; then ok; else bad "unreadable prompt crashed or succeeded"; fi
rm "$TMP/prompt-boundaries/agent/DEEPSEEK_START.md"
ln -s "$TMP/absent-prompt" "$TMP/prompt-boundaries/agent/DEEPSEEK_START.md"
set +e
out="$(cd "$TMP/prompt-boundaries" && KUJO="$KUJO" "$BIN" prompt deepseek 2>&1)"
code=$?
set -e
if [ "$code" -eq 1 ] && [[ "$out" == *'symlinked pack prompt'* ]]; then ok; else bad "dangling prompt symlink fell back"; fi
rm "$TMP/prompt-boundaries/agent/DEEPSEEK_START.md"
mkdir "$TMP/prompt-boundaries/agent/DEEPSEEK_START.md"
set +e
out="$(cd "$TMP/prompt-boundaries" && KUJO="$KUJO" "$BIN" prompt deepseek 2>&1)"
code=$?
set -e
if [ "$code" -eq 1 ] && [[ "$out" == error:* ]]; then ok; else bad "prompt directory fell back"; fi
rmdir "$TMP/prompt-boundaries/agent/DEEPSEEK_START.md"
out="$(cd "$TMP/prompt-boundaries" && KUJO="$KUJO" "$BIN" prompt deepseek 2>&1)"
if [[ "$out" == note:*'printing a default prompt.'* ]]; then ok; else bad "missing prompt fallback changed"; fi

# Auxiliary Markdown read errors must not turn into successful validation.
cp -R "$PROJECT_DIR/tests/fixtures/golden-agent" "$TMP/read-boundary"
mkdir "$TMP/read-boundary/extra"
printf '\377' > "$TMP/read-boundary/extra/NOTES.MD"
set +e
out="$(KUJO="$KUJO" "$BIN" validate --output read-boundary --json 2>&1)"
code=$?
set -e
if [ "$code" -eq 1 ] && [[ "$out" == *'Pack contains unreadable Markdown: extra/NOTES.MD'* ]]; then
  ok
else
  bad "unreadable auxiliary Markdown validated: $out"
fi
# Non-Markdown binary attachments retain their established compatibility.
mv "$TMP/read-boundary/extra/NOTES.MD" "$TMP/read-boundary/extra/attachment.bin"
if KUJO="$KUJO" "$BIN" validate --output read-boundary --json >/dev/null; then ok; else bad "binary attachment compatibility changed"; fi
printf 'FILL IN\n' > "$TMP/read-boundary/extra/NOTES.MD"
out="$(KUJO="$KUJO" "$BIN" validate --output read-boundary --json 2>&1)"
if [[ "$out" == *'Potential placeholder text remains in extra/NOTES.MD'* ]]; then ok; else bad "auxiliary Markdown placeholder warning was lost"; fi
printf 'demo\n' > "$TMP/read-boundary/extra/.ENV"
set +e
out="$(KUJO="$KUJO" "$BIN" validate --output read-boundary --json 2>&1)"
code=$?
set -e
if [ "$code" -eq 1 ] && [[ "$out" == *'Pack contains a secret-looking file: extra/.ENV'* ]]; then ok; else bad "existing uppercase secret file validated"; fi

# Doctor uses the same prompt readability/content checks as init, without a request.
mkdir "$TMP/doctor-prompt"
for prompt_kind in empty directory invalid-utf8; do
  prompt_path="$TMP/doctor-prompt/MEGA_PROMPT.md"
  case "$prompt_kind" in
    empty) : > "$prompt_path" ;;
    directory) mkdir "$prompt_path" ;;
    invalid-utf8) printf '\377' > "$prompt_path" ;;
  esac
  set +e
  out="$(cd "$TMP/doctor-prompt" && PACKWRITE_API_KEY=offline-test-placeholder KUJO="$KUJO" "$BIN" doctor --strict --json 2>&1)"
  code=$?
  set -e
  if [ "$code" -eq 1 ] && [[ "$out" == *'"prompt_status":"invalid"'* ]] && [[ "$out" == *'"ok":false'* ]]; then ok; else bad "doctor accepted $prompt_kind prompt: $out"; fi
  out="$(cd "$TMP/doctor-prompt" && PACKWRITE_API_KEY=offline-test-placeholder KUJO="$KUJO" "$BIN" doctor --json)"
  if [[ "$out" == *'"prompt_status":"invalid"'* ]] && [[ "$out" == *'"ok":false'* ]]; then ok; else bad "informational doctor lost prompt blocker"; fi
  rm -rf "$prompt_path"
done
printf '# Valid prompt\n' > "$TMP/doctor-prompt/MEGA_PROMPT.md"
out="$(cd "$TMP/doctor-prompt" && PACKWRITE_API_KEY=offline-test-placeholder KUJO="$KUJO" "$BIN" doctor --strict --json)"
if [[ "$out" == *'"prompt_status":"found"'* ]] && [[ "$out" == *'"ok":true'* ]]; then ok; else bad "doctor rejected a valid prompt"; fi

# Non-finite TOML numbers must fail before resolved configuration reaches JSON.
for numeric_case in temperature:nan timeout:nan timeout:inf; do
  numeric_field="${numeric_case%%:*}"
  numeric_value="${numeric_case#*:}"
  printf '[model]\n%s = %s\n' "$numeric_field" "$numeric_value" > "$TMP/nonfinite.toml"
  set +e
  out="$(KUJO="$KUJO" "$BIN" config --config "$TMP/nonfinite.toml" 2>&1)"
  code=$?
  set -e
  if [ "$code" -eq 1 ] && [[ "$out" == 'error: Invalid configuration:'* ]] && [[ "$out" != *'Runtime Error'* ]]; then ok; else bad "non-finite config crashed or succeeded: $out"; fi
done

# Permission failures must remain structured validation failures, not VM crashes.
# Root bypasses Unix mode bits, so these cases require an ordinary user.
if [ "$(id -u)" -ne 0 ]; then
  for denied_kind in root phases extra; do
    cp -R "$PROJECT_DIR/tests/fixtures/golden-agent" "$TMP/denied-pack"
    denied_path="$TMP/denied-pack"
    if [ "$denied_kind" != root ]; then denied_path="$denied_path/$denied_kind"; fi
    mkdir -p "$denied_path"
    chmod 000 "$denied_path"
    for denied_command in validate summary; do
      set +e
      out="$(KUJO="$KUJO" "$BIN" "$denied_command" --output denied-pack --json 2>"$TMP/denied-stderr")"
      code=$?
      set -e
      if [ "$code" -eq 1 ] && [[ "$out" == \{*\} ]] && [[ "$out" == *'"ok":false'* ]] && [[ "$out" == *'Could not read pack directory:'* ]] && [ ! -s "$TMP/denied-stderr" ]; then ok; else bad "$denied_command crashed or accepted unreadable $denied_kind directory: $out"; fi
    done
    chmod 700 "$denied_path"
    if KUJO="$KUJO" "$BIN" validate --output denied-pack --json >/dev/null; then ok; else bad "restoring $denied_kind permissions did not restore valid pack"; fi
    rm -rf "$TMP/denied-pack"
  done
else
  echo "  SKIP: 9 directory-permission assertions require a non-root user"
fi

# Context collection fails before generation instead of crashing or dropping data.
if [ "$(id -u)" -ne 0 ]; then
  mkdir -p "$TMP/context-denied/src"
  printf '# Demo\n' > "$TMP/context-denied/MEGA_PROMPT.md"
  for context_kind in root src; do
    context_path="$TMP/context-denied"
    context_mode=100
    if [ "$context_kind" = src ]; then context_path="$context_path/src"; context_mode=000; fi
    chmod "$context_mode" "$context_path"
    for context_quiet in normal quiet; do
      context_flags=(--dry-run)
      if [ "$context_quiet" = quiet ]; then context_flags+=(--quiet); fi
      set +e
      out="$(cd "$TMP/context-denied" && KUJO="$KUJO" "$BIN" init "${context_flags[@]}" 2>"$TMP/context-stderr")"
      code=$?
      set -e
      if [ "$code" -eq 1 ] && [[ "$out" == *'error: Could not read repository context directory:'* ]] && [[ "$out" != *'Requesting model output'* ]] && [ ! -s "$TMP/context-stderr" ] && [ ! -e "$TMP/context-denied/agent" ]; then ok; else bad "context $context_kind/$context_quiet failure crashed or continued: $out"; fi
    done
    chmod 700 "$context_path"
    if (cd "$TMP/context-denied" && KUJO="$KUJO" "$BIN" init --dry-run --quiet >/dev/null); then ok; else bad "context did not recover after restoring $context_kind permissions"; fi
  done
  printf '[repo_context]\nexclude = ["src"]\n' > "$TMP/context-denied/packwrite.toml"
  chmod 000 "$TMP/context-denied/src"
  if (cd "$TMP/context-denied" && KUJO="$KUJO" "$BIN" init --dry-run --quiet >/dev/null); then ok; else bad "excluded unreadable subtree blocked context collection"; fi
  chmod 700 "$TMP/context-denied/src"
else
  echo "  SKIP: 7 context-permission assertions require a non-root user"
fi

# Installation must fail honestly and preserve the supported symlink launcher.
set +e
out="$(make -s -C "$PROJECT_DIR" install PREFIX="$TMP/missing-prefix" 2>&1)"
code=$?
set -e
if [ "$code" -ne 0 ]; then ok; else bad "install succeeded without a destination bin directory"; fi
if [[ "$out" != *'linked '* ]] && [[ "$out" != *'remember to export'* ]]; then ok; else bad "failed install printed success guidance"; fi
mkdir -p "$TMP/install prefix/bin"
if make -s -C "$PROJECT_DIR" install PREFIX="$TMP/install prefix" >/dev/null && [ "$(readlink "$TMP/install prefix/bin/packwrite")" = "$BIN" ]; then ok; else bad "install did not create the expected launcher symlink"; fi
out="$(KUJO="$KUJO" "$TMP/install prefix/bin/packwrite" version)"
if [ "$out" = "$(KUJO="$KUJO" "$BIN" version)" ]; then ok; else bad "installed launcher changed version output"; fi

echo "cli integration: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
