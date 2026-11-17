#!/usr/bin/env python3
# api-verify.py — 多厂商 API 连通校验、配额探测（OpenAI 兼容协议优先）
# 用法: api-verify.py <base_url> <api_key> [model]   密钥仅本进程内存使用，不写任何文件
import sys, json, urllib.request, urllib.error, ssl
ctx = ssl._create_unverified_context()

def main():
    base, key = sys.argv[1], sys.argv[2]
    model = sys.argv[3] if len(sys.argv) > 3 else None
    url = base.rstrip('/') + ("/chat/completions" if model else "/models")
    body = json.dumps({"model": model, "max_tokens": 1,
                       "messages": [{"role": "user", "content": "ping"}]}).encode() if model else None
    req = urllib.request.Request(url, data=body, method="POST" if body else "GET",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20, context=ctx) as r:
            quota = r.headers.get("x-ratelimit-remaining-requests", "")
            print(json.dumps({"ok": True, "http": r.status, "quota_remaining": quota or "n/a"}))
    except urllib.error.HTTPError as e:
        print(json.dumps({"ok": False, "kind": "auth" if e.code in (401, 403) else "http", "code": e.code}))
        sys.exit(60)
    except Exception as e:
        print(json.dumps({"ok": False, "kind": "network", "msg": str(e)[:80]}))
        sys.exit(60)

if __name__ == "__main__":
    main()
