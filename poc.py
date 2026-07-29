#!/usr/bin/env python3
import json
import time
import urllib.error
import urllib.request

TARGET = "http://127.0.0.1:8080"
TIMEOUT = 120
PROMPT_UNIT = (
    "The quick brown fox jumps over the lazy dog. "
    "Pack my box with five dozen liquor jugs. "
)

def request_json(method, path, payload=None, timeout=TIMEOUT):
    data = None
    headers = {"Accept": "application/json"}

    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        TARGET + path,
        data=data,
        headers=headers,
        method=method,
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode("utf-8", errors="replace")
        return json.loads(body) if body else {}


def server_alive():
    try:
        request_json("GET", "/health", timeout=3)
        return True
    except Exception:
        return False


def token_count(text):
    response = request_json(
        "POST",
        "/tokenize",
        {
            "content": text,
            "add_special": True,
            "parse_special": True,
        },
    )
    return len(response["tokens"])


def build_prompt(target_tokens):
    lo = 1
    hi = 1

    while token_count(PROMPT_UNIT * hi) < target_tokens:
        hi *= 2

    best_prompt = PROMPT_UNIT
    best_count = token_count(best_prompt)

    while lo <= hi:
        mid = (lo + hi) // 2
        prompt = PROMPT_UNIT * mid
        count = token_count(prompt)

        if count <= target_tokens:
            best_prompt = prompt
            best_count = count
            lo = mid + 1
        else:
            hi = mid - 1

    return best_prompt, best_count


def main():
    if not server_alive():
        print("[-] llama-server is not running at", TARGET)
        return 1

    props = request_json("GET", "/props")
    n_ctx = props["default_generation_settings"]["n_ctx"]
    prompt, prompt_tokens = build_prompt(n_ctx - 2)

    print(f"[*] target: {TARGET}/completion")
    print(f"[*] n_ctx: {n_ctx}, prompt tokens: {prompt_tokens}")
    print("[*] sending n_keep=64, n_discard=-32")

    payload = {
        "prompt": prompt,
        "stream": False,
        "cache_prompt": False,
        "n_predict": 256,
        "n_keep": 64,
        "n_discard": -32,
        "ignore_eos": True,
        "temperature": 0.0,
        "top_k": 1,
        "top_p": 1.0,
        "seed": 1,
    }

    try:
        response = request_json("POST", "/completion", payload)
    except Exception as error:
        time.sleep(1)
        if not server_alive():
            print(f"[+] server crashed or stopped responding: {error}")
            return 0
        print(f"[-] request failed but server is still alive: {error}")
        return 1

    time.sleep(1)
    if not server_alive():
        print("[+] server crashed or stopped responding")
        return 0

    print("[-] server is still alive")
    print(json.dumps({
        "truncated": response.get("truncated"),
        "timings": response.get("timings"),
        "error": response.get("error"),
    }, indent=2))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
