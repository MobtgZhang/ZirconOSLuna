#!/usr/bin/env bash
# 从 retrage/edk2-nightly 下载 x86_64 QEMU 用 OVMF（与 build.conf 默认文件名一致）。
# 索引页：https://retrage.github.io/edk2-nightly/
#
# 可选环境变量：
#   OVMF_EDK2_VARIANT=RELEASE|DEBUG   默认 RELEASE（体积较小，常用）
#   OVMF_EDK2_BASE                    覆盖下载基址（默认 GitHub Pages bin/）

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${ROOT}/firmware/ovmf"
VARIANT="${OVMF_EDK2_VARIANT:-RELEASE}"
BASE="${OVMF_EDK2_BASE:-https://retrage.github.io/edk2-nightly/bin}"

case "$VARIANT" in
  RELEASE|DEBUG) ;;
  *)
    echo "fetch-ovmf: OVMF_EDK2_VARIANT must be RELEASE or DEBUG, got: $VARIANT" >&2
    exit 1
    ;;
esac

CODE_NAME="${VARIANT}X64_OVMF_CODE.fd"
VARS_NAME="${VARIANT}X64_OVMF_VARS.fd"

mkdir -p "$DEST"

fetch_one() {
  local name="$1"
  local url="${BASE}/${name}"
  local out="${DEST}/${name}"
  echo "fetch-ovmf: $url"
  curl -fsSL -o "$out" "$url"
  echo "  -> $out ($(wc -c < "$out") bytes)"
}

fetch_one "$CODE_NAME"
fetch_one "$VARS_NAME"
echo "fetch-ovmf: done. Point build.conf OVMF_CODE / OVMF_VARS to these files (or use defaults)."
