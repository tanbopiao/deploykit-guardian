#!/usr/bin/env python3
# archive-market.py — B3 deployment-archive market v0: turn the local deploy
# ledger into a public, static archive (JSON ledger + one HTML page).
# Design contract (v0):
#   - zero new server components: build-time render, plain static files.
#   - privacy: only fingerprints and generic labels leave the ledger —
#     never absolute paths, credentials or customer content.
#   - append-only: the source ledger is read-only here; outputs are rebuilt
#     idempotently from it.
# Usage:
#   archive-market.py build [--ledger PATH] [--out DIR]
#     (defaults: ledger ~/.deploy-kit/ledger.jsonl, out ./archive)
import sys, json, os, html, argparse

DEFAULT_LEDGER = os.environ.get("DEPLOY_LEDGER", os.path.expanduser("~/.deploy-kit/ledger.jsonl"))

# Fields copied from a ledger record into the public archive. Everything else
# (paths, payloads, customer identifiers) is dropped by construction.
def public_entry(rec):
    rep = rec.get("report", {}) or {}
    snap = os.path.basename(str(rep.get("snapshot", "")) or "")
    return {
        "package_id": rec.get("receipt", ""),
        "recorded_at": rec.get("ts", ""),
        "mode": rep.get("mode", ""),
        "profile": rep.get("profile", ""),
        "package": snap,
        "sha256": rec.get("sha256", ""),
        "status": rep.get("status", "recorded"),
    }

PAGE_TMPL = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — Deployment Archive</title>
<style>
  body {{ font-family: -apple-system, "Segoe UI", Roboto, sans-serif; margin: 0 auto; max-width: 860px; padding: 2rem 1rem; color: #1a1a2e; }}
  h1 {{ font-size: 1.5rem; }} .muted {{ color: #667; font-size: .9rem; }}
  table {{ border-collapse: collapse; width: 100%; margin-top: 1rem; font-size: .92rem; }}
  th, td {{ border: 1px solid #dde; padding: .5rem .6rem; text-align: left; word-break: break-all; }}
  th {{ background: #f4f4fb; }}
  code {{ background: #f4f4fb; padding: .1rem .3rem; border-radius: 3px; }}
  footer {{ margin-top: 2rem; }}
</style>
</head>
<body>
<h1>Deployment Archive</h1>
<p class="muted">{title} · {count} package(s) · generated {gen_at} · fingerprints only, no customer content</p>
<table>
<tr><th>Package ID</th><th>Recorded (UTC)</th><th>Mode</th><th>Profile</th><th>Package</th><th>SHA-256</th><th>Status</th></tr>
{rows}
</table>
<footer>
<p class="muted">Each row is one automated deployment recorded in the append-only local ledger. The SHA-256 column lets anyone verify the package fingerprint against their own copy. Rebuild this page any time with <code>modules/archive-market.py build</code>.</p>
</footer>
</body>
</html>
"""

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["build"])
    ap.add_argument("--ledger", default=DEFAULT_LEDGER)
    ap.add_argument("--out", default="./archive")
    ap.add_argument("--title", default="DeployKit Guardian")
    a = ap.parse_args()

    if not os.path.exists(a.ledger):
        sys.exit(f"ledger not found: {a.ledger}")
    entries = []
    with open(a.ledger, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(public_entry(json.loads(line)))
            except json.JSONDecodeError:
                continue  # a torn tail line never blocks the archive build
    if not entries:
        sys.exit("ledger has no valid records; nothing to archive")

    os.makedirs(a.out, exist_ok=True)
    ledger_out = os.path.join(a.out, "ledger.json")
    page_out = os.path.join(a.out, "index.html")
    import time
    gen_at = time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime())
    with open(ledger_out, "w", encoding="utf-8") as f:
        json.dump({"generated_at": gen_at, "count": len(entries), "packages": entries},
                  f, ensure_ascii=False, indent=2)
    rows = "\n".join(
        "<tr><td><code>{pid}</code></td><td>{ts}</td><td>{mode}</td><td>{prof}</td>"
        "<td>{pkg}</td><td><code>{sha}</code></td><td>{st}</td></tr>".format(
            pid=html.escape(e["package_id"]), ts=html.escape(e["recorded_at"]),
            mode=html.escape(e["mode"] or "-"), prof=html.escape(e["profile"] or "-"),
            pkg=html.escape(e["package"] or "-"), sha=html.escape(e["sha256"][:16] + "…"),
            st=html.escape(e["status"]))
        for e in entries)
    with open(page_out, "w", encoding="utf-8") as f:
        f.write(PAGE_TMPL.format(title=html.escape(a.title), count=len(entries),
                                 gen_at=gen_at, rows=rows))
    print(json.dumps({"archive": a.out, "packages": len(entries),
                      "ledger": ledger_out, "page": page_out}, ensure_ascii=False))

if __name__ == "__main__":
    main()
