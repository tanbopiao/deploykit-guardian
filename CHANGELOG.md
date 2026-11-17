# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- B2 post-deploy guardian v0: hourly heartbeat (outbound-only), read-only baseline
  fingerprint patrol, 3-level anomaly classification (info/warn/fault),
  static receipt page, one-command clean uninstall.
- Acceptance test `tests/test_guardian_e2e.sh` covering the full sandbox flow
  (baseline → patrol → drift → fault → page → uninstall).

### Changed
- Ledger webhook backend generalized: `LEDGER_WEBHOOK` (was vendor-specific).

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
