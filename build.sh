#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SOURCE_DIR="${SCRIPT_DIR}/../llama.cpp"
readonly VULN_COMMIT="12568ca8c8176785f5da005a5be17064c72c5536"
readonly IMAGE_NAME="${IMAGE_NAME:-llama-cve-2026-21869-asan}"

for command_name in docker git tar; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "error: required command not found: ${command_name}" >&2
        exit 1
    fi
done

if ! git -C "${SOURCE_DIR}" cat-file -e "${VULN_COMMIT}^{commit}" 2>/dev/null; then
    echo "error: vulnerable commit is unavailable in ${SOURCE_DIR}" >&2
    exit 1
fi

build_context="$(mktemp -d)"
cleanup() {
    rm -rf -- "${build_context}"
}
trap cleanup EXIT

# Export the committed tree, excluding local exploit/debug instrumentation and
# unrelated uncommitted changes present in the analysis checkout.
git -C "${SOURCE_DIR}" archive "${VULN_COMMIT}" | tar -x -C "${build_context}"
cp -- "${SCRIPT_DIR}/Dockerfile" "${build_context}/Dockerfile"

echo "[*] building ${IMAGE_NAME} from vulnerable commit ${VULN_COMMIT}"
docker build \
    --build-arg "VULN_COMMIT=${VULN_COMMIT}" \
    --tag "${IMAGE_NAME}" \
    "${build_context}"
