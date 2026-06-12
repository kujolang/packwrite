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

# --- validate passes ---
if KUJO="$KUJO" "$BIN" validate >/dev/null; then ok; else bad "validate failed on good pack"; fi

# --- prompt commands ---
if KUJO="$KUJO" "$BIN" prompt deepseek | grep -q "autonomous"; then ok; else bad "prompt deepseek missing content"; fi
if KUJO="$KUJO" "$BIN" prompt codex-review | grep -q "repair checklist"; then ok; else bad "prompt codex-review missing content"; fi

# --- prompt fallback when file absent ---
rm -rf "$TMP/agent"
if KUJO="$KUJO" "$BIN" prompt deepseek | grep -q "autonomous"; then ok; else bad "prompt deepseek fallback missing"; fi

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
for c in compare repair-pack summary; do
  out="$(KUJO="$KUJO" "$BIN" "$c" 2>&1 || true)"
  if echo "$out" | grep -q "planned for a future version"; then ok; else bad "$c missing planned message"; fi
done

# --- anthropic without endpoint fails with an OpenAI-compatible explanation ---
printf '# Demo\n' > MEGA_PROMPT.md
unset PACKWRITE_FAKE_RESPONSE_FILE
out="$(KUJO="$KUJO" "$BIN" init MEGA_PROMPT.md --provider anthropic 2>&1 || true)"
if echo "$out" | grep -q "OpenAI-compatible"; then ok; else bad "anthropic error missing OpenAI-compatible note"; fi
export PACKWRITE_FAKE_RESPONSE_FILE="$TMP/fake.json"

# --- every subcommand honors --help (exit 0 + usage, no side effects) ---
for sub in "init" "validate" "prompt" "config" "doctor"; do
  out="$(KUJO="$KUJO" "$BIN" $sub --help 2>&1)"; code=$?
  if [ "$code" -eq 0 ] && echo "$out" | grep -qi "usage"; then ok; else bad "$sub --help did not show usage with exit 0"; fi
done
# prompt deepseek --help must show help, NOT emit the prompt
out="$(KUJO="$KUJO" "$BIN" prompt deepseek --help 2>&1)"
if echo "$out" | grep -qi "usage: packwrite prompt"; then ok; else bad "prompt deepseek --help emitted prompt instead of help"; fi

# Static help output is an agent-facing contract, so keep the full text exact.
emdash="$(printf '\342\200\224')"
help_expected="$(cat <<EOF
packwrite 0.1.0 $emdash compile a mega prompt into a validated /agent pack

Usage: packwrite <command> [arguments]

Commands:
  init [file]   Generate an /agent pack from a mega prompt
  validate      Validate an existing /agent pack
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
  --debug               sanitized provider/response diagnostics
  --save-raw-response <file>  save raw model response (may contain sensitive data)
EOF
)"
out="$(KUJO="$KUJO" "$BIN" init --help 2>&1)"
if [ "$out" = "$init_help_expected" ]; then ok; else bad "init help output changed"; fi

echo ""
echo "cli integration: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
