#!/usr/bin/env python3
# site-channel.py — B4 website deployment channel v0: intake board + wizard
# guide page for non-developers.
# Design contract (v0):
#   - zero new server components: static pages rendered at build time.
#   - privacy: the public board shows order ID, type, status and timestamps
#     only — customer notes, URLs and credentials never leave the intake file.
#   - append-only intake: orders are recorded once and only transitioned by
#     explicit `set-status`; the board is rebuilt idempotently.
# Usage:
#   site-channel.py intake add --type TYPE [--note NOTE] [--orders PATH]
#   site-channel.py intake set-status --id SC-xxxx --status STATUS [--orders PATH]
#   site-channel.py board --out DIR [--orders PATH] [--title TITLE]
#   site-channel.py guide --out DIR [--title TITLE]
import sys, json, os, html, time, argparse, uuid

DEFAULT_ORDERS = os.environ.get("SITE_CHANNEL_ORDERS", os.path.expanduser("~/.deploy-kit/site-channel.jsonl"))
STATUSES = ["new", "in-progress", "deployed", "closed"]

def load_orders(path):
    orders = []
    if not os.path.exists(path):
        return orders
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                orders.append(json.loads(line))
            except json.JSONDecodeError:
                continue  # torn tail line never blocks the board
    return orders

def cmd_intake(a):
    orders = load_orders(a.orders)
    if a.sub == "add":
        order = {
            "order_id": f"SC-{uuid.uuid4().hex[:8]}",
            "type": a.type,
            "status": "new",
            "created_at": time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime()),
            "updated_at": "",
            # note is stored in the intake file but never rendered publicly
            "note": a.note or "",
        }
        os.makedirs(os.path.dirname(a.orders) or ".", exist_ok=True)
        with open(a.orders, "a", encoding="utf-8") as f:
            f.write(json.dumps(order, ensure_ascii=False) + "\n")
        print(json.dumps({"order_id": order["order_id"], "status": order["status"]}, ensure_ascii=False))
    elif a.sub == "set-status":
        if a.status not in STATUSES:
            sys.exit(f"status must be one of {STATUSES}")
        found = False
        for o in orders:
            if o.get("order_id") == a.id:
                o["status"] = a.status
                o["updated_at"] = time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime())
                found = True
        if not found:
            sys.exit(f"order not found: {a.id}")
        with open(a.orders, "w", encoding="utf-8") as f:
            for o in orders:
                f.write(json.dumps(o, ensure_ascii=False) + "\n")
        print(json.dumps({"order_id": a.id, "status": a.status}, ensure_ascii=False))

GUIDE_TMPL = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — Website Deployment Guide</title>
<style>
  body {{ font-family: -apple-system, "Segoe UI", Roboto, sans-serif; margin: 0 auto; max-width: 760px; padding: 2rem 1rem; color: #1a1a2e; line-height: 1.6; }}
  h1 {{ font-size: 1.5rem; }} h2 {{ font-size: 1.1rem; margin-top: 1.6rem; }}
  .muted {{ color: #667; font-size: .9rem; }}
  ol li {{ margin: .5rem 0; }}
  code {{ background: #f4f4fb; padding: .1rem .3rem; border-radius: 3px; }}
  .card {{ border: 1px solid #dde; border-radius: 8px; padding: 1rem 1.2rem; margin: 1rem 0; background: #fbfbff; }}
</style>
</head>
<body>
<h1>Put your website online — no coding needed</h1>
<p class="muted">{title} · website deployment channel v0</p>
<div class="card">
<h2>Step 1 — Prepare your site package</h2>
<p>Zip your website files (HTML, images, styles). No Git, no terminal, no code — a normal zip file is enough.</p>
<h2>Step 2 — Submit a deployment request</h2>
<p>Send us the package and one line about where it should run. You get an order ID like <code>SC-xxxxxxxx</code> as your receipt.</p>
<h2>Step 3 — We deploy automatically</h2>
<p>Your package goes through the same automated pipeline used for every deployment: environment precheck, install, verification — all recorded in an append-only ledger.</p>
<h2>Step 4 — Verify and go live</h2>
<p>You receive a verification receipt with the package fingerprint. The deployment archive lets anyone confirm the fingerprint of what went live.</p>
</div>
<p class="muted">Track progress on the intake board. Questions? One message is enough — we handle the rest.</p>
</body>
</html>
"""

BOARD_TMPL = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — Intake Board</title>
<style>
  body {{ font-family: -apple-system, "Segoe UI", Roboto, sans-serif; margin: 0 auto; max-width: 860px; padding: 2rem 1rem; color: #1a1a2e; }}
  h1 {{ font-size: 1.5rem; }} .muted {{ color: #667; font-size: .9rem; }}
  table {{ border-collapse: collapse; width: 100%; margin-top: 1rem; font-size: .92rem; }}
  th, td {{ border: 1px solid #dde; padding: .5rem .6rem; text-align: left; }}
  th {{ background: #f4f4fb; }}
  .new {{ color: #b45309; }} .in-progress {{ color: #1d4ed8; }} .deployed {{ color: #047857; }} .closed {{ color: #667; }}
</style>
</head>
<body>
<h1>Deployment Intake Board</h1>
<p class="muted">{title} · {count} request(s) · generated {gen_at} · order IDs and status only, no customer details</p>
<table>
<tr><th>Order ID</th><th>Type</th><th>Status</th><th>Created (UTC)</th><th>Updated (UTC)</th></tr>
{rows}
</table>
</body>
</html>
"""

def cmd_board(a):
    orders = load_orders(a.orders)
    os.makedirs(a.out, exist_ok=True)
    gen_at = time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime())
    rows = "\n".join(
        '<tr><td><code>{oid}</code></td><td>{typ}</td><td class="{st}">{st}</td>'
        "<td>{c}</td><td>{u}</td></tr>".format(
            oid=html.escape(o.get("order_id", "")), typ=html.escape(o.get("type", "-")),
            st=html.escape(o.get("status", "-")), c=html.escape(o.get("created_at", "")),
            u=html.escape(o.get("updated_at", "") or "-"))
        for o in orders)
    with open(os.path.join(a.out, "board.html"), "w", encoding="utf-8") as f:
        f.write(BOARD_TMPL.format(title=html.escape(a.title), count=len(orders),
                                  gen_at=gen_at, rows=rows))
    with open(os.path.join(a.out, "orders.json"), "w", encoding="utf-8") as f:
        json.dump({"generated_at": gen_at, "count": len(orders),
                   "orders": [{k: o.get(k, "") for k in ("order_id", "type", "status",
                                                         "created_at", "updated_at")}
                              for o in orders]}, f, ensure_ascii=False, indent=2)
    print(json.dumps({"board": a.out, "orders": len(orders)}, ensure_ascii=False))

def cmd_guide(a):
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "guide.html"), "w", encoding="utf-8") as f:
        f.write(GUIDE_TMPL.format(title=html.escape(a.title)))
    print(json.dumps({"guide": os.path.join(a.out, "guide.html")}, ensure_ascii=False))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["intake", "board", "guide"])
    ap.add_argument("sub", nargs="?", default=None, help="intake subcommand: add | set-status")
    ap.add_argument("--orders", default=DEFAULT_ORDERS)
    ap.add_argument("--out", default="./channel")
    ap.add_argument("--title", default="DeployKit Guardian")
    ap.add_argument("--type", default=None)
    ap.add_argument("--note", default=None)
    ap.add_argument("--id", default=None)
    ap.add_argument("--status", default=None)
    a = ap.parse_args()
    if a.cmd == "intake":
        if a.sub is None:
            a.sub = "add" if a.type else "set-status"
        if a.sub == "add" and not a.type:
            sys.exit("intake add requires --type")
        if a.sub == "set-status" and not (a.id and a.status):
            sys.exit("intake set-status requires --id and --status")
        cmd_intake(a)
    elif a.cmd == "board":
        cmd_board(a)
    elif a.cmd == "guide":
        cmd_guide(a)

if __name__ == "__main__":
    main()
