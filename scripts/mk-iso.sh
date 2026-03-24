#!/usr/bin/env bash
# 生成 ZirconOS Boot Manager（UEFI）可引导 ISO。
# 用法：
#   mk-iso.sh <BOOTX64.efi> <out.iso> <kernel_elf>
# 将内核复制为 \BOOT\ZKERNEL.ELF 与 \BOOT\ZKERNEL_X64.ELF，并复制 boot/conf/zbm.ini → \BOOT\zbm.ini（若存在）。
# 额外 mcopy 对（可选，成对出现）：每个 <src> <dst> 中 dst 可为 BOOT/foo 或 ::BOOT/foo
set -euo pipefail
ZBM_EFI="${1:?}"
ISO="${2:?}"
KERNEL="${3:?}"

command -v mkfs.fat >/dev/null || { echo "mk-iso: 需要 mkfs.fat（dosfstools）" >&2; exit 1; }
command -v mcopy >/dev/null || { echo "mk-iso: 需要 mcopy（mtools）" >&2; exit 1; }
command -v xorriso >/dev/null || { echo "mk-iso: 需要 xorriso" >&2; exit 1; }

[[ -f "$ZBM_EFI" ]] || { echo "mk-iso: 未找到 ZBM: $ZBM_EFI" >&2; exit 1; }
[[ -f "$KERNEL" ]] || { echo "mk-iso: 未找到内核: $KERNEL" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ZBM_INI_SRC="$REPO_ROOT/boot/conf/zbm.ini"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

EFIBOOT_IMG="$WORKDIR/efiboot.img"
dd if=/dev/zero of="$EFIBOOT_IMG" bs=1M count=64 status=none
mkfs.fat -F 16 -n ZIRCONZBM "$EFIBOOT_IMG" >/dev/null

mmd -i "$EFIBOOT_IMG" ::EFI ::EFI/BOOT ::BOOT 2>/dev/null || true
mcopy -i "$EFIBOOT_IMG" "$ZBM_EFI" ::EFI/BOOT/BOOTX64.EFI
mcopy -i "$EFIBOOT_IMG" "$KERNEL" ::BOOT/ZKERNEL.ELF
mcopy -i "$EFIBOOT_IMG" "$KERNEL" ::BOOT/ZKERNEL_X64.ELF

if [[ -f "$ZBM_INI_SRC" ]]; then
  mcopy -i "$EFIBOOT_IMG" "$ZBM_INI_SRC" ::BOOT/zbm.ini
fi

shift 3
while (($# >= 2)); do
  SRC="$1"
  DST="$2"
  shift 2
  [[ -f "$SRC" ]] || { echo "mk-iso: skip missing $SRC" >&2; continue; }
  if [[ "$DST" == ::* ]]; then
    mcopy -i "$EFIBOOT_IMG" "$SRC" "$DST"
  else
    mcopy -i "$EFIBOOT_IMG" "$SRC" "::${DST}"
  fi
done

STAGING="$WORKDIR/staging"
mkdir -p "$STAGING"
cp -f "$EFIBOOT_IMG" "$STAGING/efiboot.img"

xorriso -as mkisofs -quiet -o "$ISO" \
  -V ZIRCONOSLUNA \
  -R -J \
  -eltorito-alt-boot \
  -e efiboot.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  "$STAGING"

echo "Created $ISO (ZirconOS Boot Manager UEFI + zbm.ini)"
