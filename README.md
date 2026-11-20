# DeployKit Guardian

**English** · [简体中文](README.zh-CN.md)

> One command to deploy. One guardian watching after it.

**Deploy once, guarded for life.**

DeployKit Guardian is an open-source **post-deploy guardian** for systems installed by one-click deploy kits. When the installer finishes, the real-world pain begins: who watches the system, how do you notice drift, what breaks silently. Guardian answers this: **the deployed system speaks for itself.**

- **B1 — One-click deploy kit** (included): fully scripted deploy with precheck, troubleshooting, snapshots and an append-only audit ledger.
- **B2 — Post-deploy guardian v0** (included): hourly heartbeat (outbound-only), read-only baseline fingerprint checks, 3-level anomaly classification, and a static receipt page.
- **B3 — Deploy archive market** (planned): public archive of deploy packages with environment fit and verification records.
- **B4 — Website deploy channel** (planned): drag-and-drop publishing for non-developers.

## Quick start

```sh
# deploy (dry-run validates profile and pipeline)
./start.sh deploy profiles/codex.json --dry-run

# real deploy
./start.sh deploy profiles/codex.json

# register baseline fingerprints right after deploy
./start.sh guardian baseline add /opt/myapp/main.conf

# start hourly heartbeat + patrol (outbound-only)
./start.sh guardian heartbeat start

# view receipts
./start.sh guardian page   # open ~/.guardian/page/receipt.html
```

`start.sh` is a thin wrapper around the unified Python entry `start.py` (see
[Platform support](#platform-support)); the plain `bash start-auto-deploy.sh …`
and `guardian/guardian.sh …` paths remain fully valid and unchanged.

## Platform support

| Feature | Linux | macOS | Windows native | WSL2 |
| --- | --- | --- | --- | --- |
| B1 deploy pipeline | ✅ (bash, original path) | ✅ | via WSL2 (`start.py deploy` delegates automatically when WSL2 is present) | ✅ |
| B2 guardian core | ✅ cron heartbeat | ✅ cron heartbeat (default) | — | ✅ cron heartbeat |
| B2 guardian native scheduling | — | optional launchd adapter (`guardian/adapters/macos/`) | ✅ schtasks hourly task (`guardian/adapters/windows/guardian.ps1`) | — |
| Receipt page, patrol, clean uninstall | ✅ | ✅ | ✅ | ✅ |
| Entry point | `start.sh` / `start.command` | `start.sh` / `start.command` (double-click friendly) | `start.cmd` (calls `start.py`, delegates guardian to the PowerShell adapter) | `start.sh` |

All platforms share the same design guarantees: outbound-only, read-only
patrol, fingerprints only (never file contents), one-command clean uninstall
(`start.py guardian uninstall` / `guardian.ps1 uninstall`). Platform
differences (scheduling, hashing tool, outbound request) are confined to
[`guardian/adapters/`](guardian/adapters/README.md).

## Design guarantees (v0)

| Guarantee | How |
| --- | --- |
| Outbound-only | Guardian never opens inbound ports; heartbeat and webhook are client-side POSTs |
| Read-only checks | Patrol compares fingerprints; it never rewrites the guarded system |
| Drift is recorded, not repaired | Auto-repair is out of scope for v0 (see ROADMAP) |
| Clean uninstall | `guardian.sh uninstall` removes cron entry and all files in one command |
| Privacy | Receipts and webhooks carry fingerprints only, never file contents |

## Guardian levels

- `info` — all registered baselines match
- `warn` — drift detected (content changed)
- `fault` — baseline file removed (or check script failure escalated)

## Deployment archive (B3)

Every automated deploy is recorded in an append-only local ledger. One command
turns it into a public, static archive — a JSON ledger plus a single-file HTML
page showing package ID, environment profile, verification status and SHA-256
fingerprint. Customer content and absolute paths never leave the ledger:

```sh
python3 modules/archive-market.py build --out ./archive
```

## Website deployment channel (B4)

For non-developers: a four-step wizard guide page (prepare zip → submit
request → automated deploy → verify receipt) plus an intake board showing
order ID, type and status. Customer notes never appear on the public board:

```sh
python3 modules/site-channel.py intake add --type static-site
python3 modules/site-channel.py board --out ./channel
python3 modules/site-channel.py guide --out ./channel
```

## Repository layout

```
├── start.py                # unified cross-platform entry (deploy / guardian)
├── start.sh                # POSIX thin wrapper (Linux / macOS / WSL2)
├── start.command           # macOS thin wrapper (double-click friendly)
├── start.cmd               # Windows thin wrapper
├── start-auto-deploy.sh    # B1 orchestrator (precheck → deploy → verify → ledger)
├── guardian/               # B2 post-deploy guardian v0
│   ├── guardian.sh         # heartbeat / patrol / page / uninstall (cron default)
│   └── adapters/           # platform adaptation layer (windows / macos)
├── lib/ modules/ profiles/ adapters/   # B1 modules (incl. archive-market.py, site-channel.py)
├── examples/               # worked examples
├── tests/                  # acceptance tests (sandbox e2e + entry dispatch)
├── docs/                   # install guide, design docs
└── ROADMAP.md              # B-series product line plan
```

## Status

- B1: shipped (v1.1), used in production deploys.
- B2: v0 implemented, sandbox acceptance passing (see `tests/e2e-run-*.log`).
- B3: v0 implemented, sandbox acceptance passing (13/13, `tests/test_archive_market.sh`).
- B4: v0 implemented, sandbox acceptance passing (13/13, `tests/test_site_channel.sh`).

## License

MIT — see [LICENSE](LICENSE).
