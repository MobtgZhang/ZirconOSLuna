#!/usr/bin/env bash
# QEMU 启动内核 ISO：支持 Legacy (mbr) 与 UEFI（OVMF pflash）。
# 用法：run-qemu.sh <qemu_bin> <mem> <iso> <boot_method> <ovmf_code> <ovmf_vars_dst> <ovmf_vars_src> <nographic_0_or_1>
set -euo pipefail
QEMU_BIN="${1:?}"
MEM="${2:?}"
ISO="${3:?}"
BOOT_METHOD="${4:?}"
OVMF_CODE="${5:?}"
OVMF_VARS_DST="${6:?}"
OVMF_VARS_SRC="${7:?}"
NOGFX="${8:?}"

ARGS=(-m "$MEM" -cdrom "$ISO" -boot d -vga std -serial stdio -no-reboot)

if [[ "$BOOT_METHOD" == "uefi" ]]; then
  if [[ ! -f "$OVMF_CODE" ]]; then
    echo "run-qemu: UEFI 需要 OVMF_CODE，未找到: $OVMF_CODE" >&2
    echo "  从 edk2-nightly 获取：make fetch-ovmf（https://retrage.github.io/edk2-nightly/）" >&2
    echo "  或安装发行版 ovmf 包并设置 OVMF_CODE/OVMF_VARS；或 build.conf 中 BOOT_METHOD=mbr" >&2
    exit 1
  fi
  if [[ ! -f "$OVMF_VARS_SRC" ]]; then
    echo "run-qemu: 未找到 OVMF_VARS 模板: $OVMF_VARS_SRC" >&2
    echo "  同上：make fetch-ovmf 或手动指定 -Dovmf-vars=..." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$OVMF_VARS_DST")"
  if [[ ! -f "$OVMF_VARS_DST" ]]; then
    cp -f "$OVMF_VARS_SRC" "$OVMF_VARS_DST"
  fi
  ARGS+=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE")
  ARGS+=(-drive "if=pflash,format=raw,file=$OVMF_VARS_DST")
fi

if [[ "$NOGFX" == "1" ]]; then
  ARGS+=(-display none)
fi

exec "$QEMU_BIN" "${ARGS[@]}"
