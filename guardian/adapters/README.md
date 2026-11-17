# Guardian platform adapters

Platform differences for the B2 guardian converge here. The core logic lives
in `guardian/guardian.sh` and is platform-neutral in intent (outbound-only,
read-only patrol, fingerprints only, clean uninstall); adapters provide the
platform-specific pieces: **scheduling mechanism, paths, hashing tool and
outbound request**.

| Adapter | Platform | Scheduling | Fingerprint (SHA256) | Outbound request | Receipt page |
| --- | --- | --- | --- | --- | --- |
| core (`guardian.sh`) | Linux / macOS / WSL2 (default) | cron `@hourly` | `sha256sum` | `curl` | `~/.guardian/page/receipt.html` |
| `macos/` (optional) | macOS | launchd LaunchAgent (`StartInterval 3600`) | (same as core) | (same as core) | (same as core) |
| `windows/` | Windows native (PowerShell 5.1+) | `schtasks /SC HOURLY` | `Get-FileHash` | `Invoke-WebRequest` | `~\.guardian\page\receipt.html` |

Contract for every adapter:

1. Same CLI surface as the core: `baseline add|list`, `patrol`,
   `heartbeat run|start|stop|cron`, `page`, `uninstall`.
2. Outbound-only: no inbound ports, ever. Webhook POSTs only when
   `GUARDIAN_WEBHOOK_URL` is set; failure never blocks.
3. Payloads carry fingerprints and levels only, never file contents.
4. One-command clean uninstall: removes the scheduled job and every file
   under `GUARDIAN_HOME`, nothing else.
5. State layout mirrors the core (`baseline/`, `state/`, `reports/`,
   `page/`, `guardian.log`) so the receipt page and reports remain portable.
