# Changelog

All notable changes to PackWrite are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-08-08

PackWrite 1.0 stabilizes the local prompt-to-agent-pack compiler, including
offline fake-response validation, staged path-safe writes, deterministic pack
validation, and the documented CLI/configuration contracts.

### Added

- `packwrite doctor --strict` exits non-zero when a blocking issue would stop `init`
  (no resolvable endpoint, no API key, or a missing mega prompt), making `doctor`
  usable as a CI gate. Plain `doctor` still always exits `0`.

### Changed

- Numeric CLI flags (`--temperature`, `--timeout`) are now validated up front: a
  malformed or out-of-range value returns a clear, actionable error instead of crashing
  the runtime with an uncaught parse exception. `--temperature` is bounded to `0.0`–`2.0`
  and `--timeout` must be positive.

### Security

- Added output-directory validation so configured pack directories must stay relative,
  non-empty, and non-traversing before model calls or filesystem operations.
- Rejected secret-looking generated manifest paths before dry-runs or writes report
  success, and made manifest traversal checks segment-aware.
- Hardened manifest path validation further: in addition to absolute paths and `..`
  traversal, the sandbox now rejects backslash separators and `~` home-expansion
  prefixes so a model-supplied path cannot escape the output directory on non-POSIX
  layouts.

### Docs

- Added launch-readiness Spec and Eval metadata for the Kujo prelaunch review.
- Documented production-readiness scope, intentional root-file layout, and the latest
  follow-up review backlog.
- Improved contributor/agent guidance around canonical examples, search hygiene, and
  generated/bulk path exclusions.
- Tightened quickstart and provider recipe snippets so copyable docs examples are
  easier to run.
- Reduced repeated CLI help-output printing through a small local line helper, backed by
  exact CLI help-output assertions.
