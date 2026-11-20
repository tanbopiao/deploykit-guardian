# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-20

### Added
- B2 post-deploy guardian v0: hourly heartbeat (outbound-only), read-only baseline
  fingerprint patrol, 3-level anomaly classification (info/warn/fault),
  static receipt page, one-command clean uninstall.
- Acceptance test `tests/test_guardian_e2e.sh` covering the full sandbox flow
  (baseline → patrol → drift → fault → page → uninstall).
- Cross-platform adaptation (ROADMAP item): unified Python entry `start.py`
  (auto-detects python3/python; subcommands `deploy` and `guardian`), with
  thin per-platform wrappers `start.sh` (POSIX), `start.command` (macOS,
  double-click friendly) and `start.cmd` (Windows). POSIX behavior is
  unchanged (delegates to `start-auto-deploy.sh` / `guardian/guardian.sh`).
- Guardian platform adapter layer `guardian/adapters/`: Windows native
  PowerShell adapter (`schtasks` hourly heartbeat, `Get-FileHash` SHA256
  patrol, `Invoke-WebRequest` outbound-only reporting, receipt page, clean
  uninstall — outbound-only, fingerprints only) and optional macOS launchd
  adapter; cron remains the default scheduler. Platform differences
  (scheduling, paths, hashing tool, outbound request) are confined to the
  adapters; core logic untouched.
- Entry dispatch test `tests/test_start_py_dispatch.sh` (POSIX dispatch is
  real-run; Windows adapter logic is verified under pwsh when available,
  otherwise marked SKIP — real-environment first run to be confirmed once).

### Changed
- Ledger webhook backend generalized: `LEDGER_WEBHOOK` (was vendor-specific).
- Docs: platform support matrix added to `docs/INSTALL.md` and both READMEs
  (Linux / macOS / Windows native / WSL2).

## [B1 v1.1] — 2026-11-05

### Added
- Deploy profile `deepseek-codex` (DeepSeek API via Codex).
- Customer onboarding quick-guide generation (verify command, common errors,
  support entry) auto-delivered after deploy.

### Changed
- Orchestrator hardening: fuse counter (3 consecutive failures → stop, human handoff).

## [B1 v1.0] — 2026-11-05

### Added
- Initial release: one-click deploy kit with precheck, env baseline,
  target deploy, API verify, snapshot backup, append-only audit ledger (JSONL + SHA256 receipts).
