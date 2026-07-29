#!/usr/bin/env bash
set -euo pipefail

readonly IMAGE_NAME="${IMAGE_NAME:-llama-cve-2026-21869-asan}"
readonly HOST_PORT="${HOST_PORT:-8080}"

if ! command -v docker >/dev/null 2>&1; then
    echo "error: required command not found: docker" >&2
    exit 1
fi

if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo "error: image not found: ${IMAGE_NAME} (run ./build.sh first)" >&2
    exit 1
fi

echo "[*] starting ASAN server on http://127.0.0.1:${HOST_PORT}"
echo "[*] run 'python3 poc.py' from another terminal"

exec docker run \
    --rm \
    --publish "127.0.0.1:${HOST_PORT}:8080" \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --read-only \
    --tmpfs /tmp:rw,nosuid,nodev,noexec,size=64m \
    "${IMAGE_NAME}"
