# Security Policy

PackWrite is a local-first developer tool. It runs on your machine, reads your repo,
and talks to exactly one network endpoint: the AI model you configure. This document
describes its security model and how to report a vulnerability.

## Security model

PackWrite is designed to minimize what leaves your machine.

- **API keys are read from the environment only.** They are never accepted via CLI
  flags, never read from `packwrite.toml`, and never written to disk or logs.
  Resolution order: `PACKWRITE_API_KEY`, then a provider-specific variable
  (`DEEPSEEK_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`).
- **The repository is never uploaded.** PackWrite sends the model a *lightweight*
  context summary: the root directory name, a one-line README excerpt, the names of
  manifest/config files present, and a one-level-deep listing of included directories.
  **File contents are not sent** (other than the single README summary line).
- **Secrets are excluded by default.** `.env*`, `*.pem`, `*.key`, `id_rsa`,
  `id_ed25519`, `.git`, `node_modules`, `vendor`, `dist`, `build`, `.next`,
  `coverage`, `target`, `.venv` and similar are excluded from context. Any
  secret-looking path is skipped and surfaced as a warning.
- **Prompt payloads are not logged** unless you explicitly pass `--verbose`.
- **Writes are sandboxed to the output directory.** Manifest paths from the model are
  validated before any write: absolute paths, `..` traversal, and paths escaping the
  configured output dir (`agent/` by default) are rejected.
- **No destructive actions.** PackWrite never installs dependencies, never runs
  arbitrary commands, and (on `--overwrite`) only prunes files inside its own output
  directory.

## Your responsibilities

- Treat the configured model endpoint as a third party. The mega prompt and the
  lightweight context summary are sent to it. Do not put secrets in `MEGA_PROMPT.md`
  or in the first content line of your `README.md`.
- Keep API keys in your environment / secret manager, not in committed files.
- Review a generated `/agent` pack before handing it to an autonomous agent.

## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.1.x   | ✅        |

## Reporting a vulnerability

Please report security issues privately rather than opening a public issue.

- Use GitHub's **"Report a vulnerability"** (Security advisories) on this repository, or
- email the maintainer listed in the repository profile.

Include the version (`packwrite version`), reproduction steps, and impact. You can
expect an acknowledgement within a few business days. Please give a reasonable window
to release a fix before public disclosure.
