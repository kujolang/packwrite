# PackWrite final audit pass — October 12, 2026

Repository: `kujolang/packwrite`; starting branch `main`, clean at
`3f328647e929f2622fac10ac5187f71bfc3402b1`.

## Evidence and changes

The final review revisited filename privacy rules, recursive validation/read errors,
and staged-write failure boundaries. Only two reproduced defects were changed:

| Defect | Baseline evidence | Fix | Compatibility proof |
| --- | --- | --- | --- |
| Built-in secret basename checks were case-sensitive, unlike secret extensions and secret/token substring checks | An offline manifest containing `agent/.ENV` generated successfully (exit 0) | Normalize case for built-in `.env*` and credential/key basenames in `is_excluded` and `looks_secret`; the shared policy covers context, manifest checks and existing-pack scans | Custom include/exclude rules remain exact and case-sensitive; ordinary uppercase names stay valid. Unit tests cover mixed-case names, context omission, dry-run/write refusal and no output; CLI checks nested existing `.ENV`. |
| Auxiliary Markdown read failures became empty strings during placeholder scanning | Adding invalid UTF-8 `agent/NOTES.md` to the golden pack returned exit 0 and `{"errors":[],"ok":true,"warnings":[]}` | Use the guarded read envelope in recursive scanning; report unreadable `.md` files (case-insensitive extension) as structured validation errors | Non-Markdown binary attachments remain supported; readable auxiliary Markdown still receives placeholder warnings. CLI tests exercise unreadable nested `NOTES.MD`, binary compatibility and warning preservation. |

No speculative parser, transaction, retry or runtime redesign was made. Existing
filesystem race limitations remain as documented in the first audit. The scan still
rejects symlinks before reading and preserves required-document checks.

## Verification and compatibility

- Baseline: `make test` passed 218 unit + 74 CLI assertions on Kujo 1.5.0.
- Final local suite: 229 unit + 78 CLI assertions (15 added regressions).
- `make test` includes all source/test static checks and Bash syntax checks.
- `make smoke` and `git diff --check` passed.
- Hosted CI is run on the exact candidate commit with the pinned Kujo 1.2.2 runtime
  before advancing `main`; the artifact guard also checks the commit.
- Public function signatures, commands, help, successful output, manifest/JSON
  schemas, config keys, environment variables and dependency surface are unchanged.
- Intentional stricter behavior is limited to case variants of built-in secret
  filenames and unreadable Markdown. Configured path matching and binary attachments
  are explicitly covered for compatibility.
- No performance or token improvement is claimed. No live provider was contacted.
- No newly established unresolved blocker or mandatory cross-repository change.

Implementation and documentation commits can be identified with
`git log --format='%H %s' 3f32864..HEAD`; hosted results and final SHA are also
recorded in the session's Strata handoff.
