[PASS] minimal version command succeeds
[PASS] valid existing pack validates
[PASS] offline typical dry-run succeeds
[FAIL] nested output promotes safely — Command failed with exit code 1
[FAIL] wrong-type overwrite config is rejected — Command failed with exit code 1
[FAIL] large invalid response fails within bounded time and output — Command failed with exit code 1
[PASS] oversized response is rejected before amplification
[FAIL] raw response refuses overwrite and preserves evidence — Command failed with exit code 1
[FAIL] read-only summary is machine-consumable — Command failed with exit code 2
[FAIL] doctor JSON preserves strict failure semantics — Command failed with exit code 5
[FAIL] symlinked output ancestor cannot redirect writes — Command failed with exit code 1
# Eval Report: packwrite-hardening-before-after

## Summary

| Metric | Value |
|--------|-------|
| Suite | packwrite-hardening-before-after |
| Version | 0.0.0 |
| Total Tests | 11 |
| Passed | 4 |
| Failed | 7 |
| Duration | 29315ms |
| Parallel Requested | false |
| Parallel Used | false |
| Parallel Mode | serial |
| Parallel Workers | 1 |
| Pass Rate | 0% |

### Result: ❌ 7 FAILED

## Test Results

| # | Status | Test | Check | Message |
|---|--------|------|-------|---------|
| 1 | ✅ | minimal version command succeeds | command_succeeds | Command succeeded (exit 0) |
| 2 | ✅ | valid existing pack validates | command_succeeds | Command succeeded (exit 0) |
| 3 | ✅ | offline typical dry-run succeeds | command_succeeds | Command succeeded (exit 0) |
| 4 | ❌ | nested output promotes safely | command_succeeds | Command failed with exit code 1 |
| 5 | ❌ | wrong-type overwrite config is rejected | command_succeeds | Command failed with exit code 1 |
| 6 | ❌ | large invalid response fails within bounded time and output | command_succeeds | Command failed with exit code 1 |
| 7 | ✅ | oversized response is rejected before amplification | command_succeeds | Command succeeded (exit 0) |
| 8 | ❌ | raw response refuses overwrite and preserves evidence | command_succeeds | Command failed with exit code 1 |
| 9 | ❌ | read-only summary is machine-consumable | command_succeeds | Command failed with exit code 2 |
| 10 | ❌ | doctor JSON preserves strict failure semantics | command_succeeds | Command failed with exit code 5 |
| 11 | ❌ | symlinked output ancestor cannot redirect writes | command_succeeds | Command failed with exit code 1 |

## Failed Test Details

### nested output promotes safely

- **Check**: `command_succeeds`
- **Message**: Command failed with exit code 1
- **allowed_command_patterns**: []
- **allowed_commands**: []
- **blocked_arg_patterns**: []
- **command**: PW_R=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite PW_V=baseline PW_K=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/../kujo/target/release/kujo bash "/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/.pw-case.sh" nested-output
- **command_pattern_match_mode**: substring
- **exit_code**: 1
- **stderr**:
- **stdout**:

### wrong-type overwrite config is rejected

- **Check**: `command_succeeds`
- **Message**: Command failed with exit code 1
- **allowed_command_patterns**: []
- **allowed_commands**: []
- **blocked_arg_patterns**: []
- **command**: PW_R=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite PW_V=baseline PW_K=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/../kujo/target/release/kujo bash "/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/.pw-case.sh" config-type
- **command_pattern_match_mode**: substring
- **exit_code**: 1
- **stderr**:
- **stdout**:

### large invalid response fails within bounded time and output

- **Check**: `command_succeeds`
- **Message**: Command failed with exit code 1
- **allowed_command_patterns**: []
- **allowed_commands**: []
- **blocked_arg_patterns**: []
- **command**: PW_R=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite PW_V=baseline PW_K=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/../kujo/target/release/kujo bash "/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/.pw-case.sh" invalid-large
- **command_pattern_match_mode**: substring
- **exit_code**: 1
- **stderr**:
- **stdout**:

### raw response refuses overwrite and preserves evidence

- **Check**: `command_succeeds`
- **Message**: Command failed with exit code 1
- **allowed_command_patterns**: []
- **allowed_commands**: []
- **blocked_arg_patterns**: []
- **command**: PW_R=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite PW_V=baseline PW_K=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/../kujo/target/release/kujo bash "/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/.pw-case.sh" raw-no-overwrite
- **command_pattern_match_mode**: substring
- **exit_code**: 1
- **stderr**:
- **stdout**:

### read-only summary is machine-consumable

- **Check**: `command_succeeds`
- **Message**: Command failed with exit code 2
- **allowed_command_patterns**: []
- **allowed_commands**: []
- **blocked_arg_patterns**: []
- **command**: PW_R=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite PW_V=baseline PW_K=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/../kujo/target/release/kujo bash "/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/.pw-case.sh" summary-json
- **command_pattern_match_mode**: substring
- **exit_code**: 2
- **stderr**:
- **stdout**:

### doctor JSON preserves strict failure semantics

- **Check**: `command_succeeds`
- **Message**: Command failed with exit code 5
- **allowed_command_patterns**: []
- **allowed_commands**: []
- **blocked_arg_patterns**: []
- **command**: PW_R=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite PW_V=baseline PW_K=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/../kujo/target/release/kujo bash "/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/.pw-case.sh" doctor-json
- **command_pattern_match_mode**: substring
- **exit_code**: 5
- **stderr**: jq: parse error: Invalid numeric literal at line 1, column 10

- **stdout**:

### symlinked output ancestor cannot redirect writes

- **Check**: `command_succeeds`
- **Message**: Command failed with exit code 1
- **allowed_command_patterns**: []
- **allowed_commands**: []
- **blocked_arg_patterns**: []
- **command**: PW_R=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite PW_V=baseline PW_K=/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/../kujo/target/release/kujo bash "/Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/.pw-case.sh" symlink-output
- **command_pattern_match_mode**: substring
- **exit_code**: 1
- **stderr**:
- **stdout**:

---
*Report generated by Eval*


Report saved to: /Users/robertdevore/2026/Kujolang/kujo-repos/packwrite/benchmarks/hardening/results/eval-baseline/eval-report.md
