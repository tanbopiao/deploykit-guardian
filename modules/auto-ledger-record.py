#!/usr/bin/env python3
# auto-ledger-record.py — audit ledger: local JSONL append + SHA256 receipt (optional webhook backend)
# 用法: auto-ledger-record.py <交付报告JSON路径>
import sys, json, hashlib, os, time
LEDGER = os.environ.get("DEPLOY_LEDGER", os.path.expanduser("~/.deploy-kit/ledger.jsonl"))
report_path = sys.argv[1]
raw = open(report_path, "rb").read()
digest = hashlib.sha256(raw).hexdigest()
rec = {"ts": time.strftime("%Y-%m-%d %H:%M:%S"), "sha256": digest,
       "report": json.loads(raw), "receipt": f"DK-{digest[:16]}"}
os.makedirs(os.path.dirname(LEDGER), exist_ok=True)
with open(LEDGER, "a") as f:   # 只增不覆盖（元法第四条）
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
# Optional webhook backend: set LEDGER_WEBHOOK to push each record; failures never block the local ledger.
hook = os.environ.get("LEDGER_WEBHOOK")
if hook:
    try:
        import urllib.request
        req = urllib.request.Request(hook, json.dumps(rec).encode(),
                                     {"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        print(f"feishu push skipped: {str(e)[:60]}")
print(json.dumps({"receipt": rec["receipt"], "sha256": digest, "ledger": LEDGER}, ensure_ascii=False))
