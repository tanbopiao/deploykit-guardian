# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| main branch | ✅ |
| B1 v1.0 / v1.1 | ✅ |
| earlier | ❌ |

## Reporting a vulnerability

Please report vulnerabilities privately:

1. Open a **security advisory** via the repository's "Security" tab (preferred), or
2. Contact the maintainers through the issue tracker asking for a private channel.

Please include: affected component (B1 deploy kit / B2 guardian), reproduction
steps, and impact assessment. We aim to acknowledge reports within 7 days.

## What we consider in scope

- Guardian components opening inbound ports (design violation)
- Guardian modifying the guarded system (design violation)
- Secret leakage: API keys or tokens persisting to disk or snapshots
- Fingerprint/report pages leaking file contents
- Ledger injection or history tampering (append-only violation)

## Out of scope

- Vulnerabilities in upstream CLIs deployed via profiles (report to the upstream vendor)
- Social engineering against end users

## Design guarantees we hold ourselves to

- Secrets live in memory only during the deploy flow, destroyed afterwards.
- Receipts and webhooks carry fingerprints/levels only, never file contents.
- Audit ledger is append-only.
- Uninstall removes everything, no residue.
