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
bash start-auto-deploy.sh profiles/codex.json --dry-run

# real deploy
bash start-auto-deploy.sh profiles/codex.json

# register baseline fingerprints right after deploy
guardian/guardian.sh baseline add /opt/myapp/main.conf

# start hourly heartbeat + patrol (outbound-only)
guardian/guardian.sh heartbeat start

# view receipts
guardian/guardian.sh page   # open ~/.guardian/page/receipt.html
```

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

## Repository layout

```
├── start-auto-deploy.sh    # B1 orchestrator (precheck → deploy → verify → ledger)
├── guardian/               # B2 post-deploy guardian v0
│   └── guardian.sh         # heartbeat / patrol / page / uninstall
├── lib/ modules/ profiles/ adapters/   # B1 modules
├── examples/               # worked examples
├── tests/                  # acceptance tests (sandbox e2e)
├── docs/                   # install guide, design docs
└── ROADMAP.md              # B-series product line plan
```

## Status

- B1: shipped (v1.1), used in production deploys.
- B2: v0 implemented, sandbox acceptance passing (see `tests/e2e-run-*.log`).
- B3/B4: planned, see [ROADMAP.md](ROADMAP.md).

## License

MIT — see [LICENSE](LICENSE).
