#!/usr/bin/env bash
# 生成 ZirconOS Boot Manager（UEFI）可引导 ISO：FAT 映像 efiboot.img（在 ISO 根目录）作为 El Torito EFI 启动项。
# 依赖：mkfs.fat（dosfstools）、mtools（mcopy）、xorriso
# 用法：mk-iso.sh <BOOTX64.efi> <kernel_elf> <out.iso>
set -euo pipefail
ZBM_EFI="${1:?}"
KERNEL="${2:?}"
ISO="${3:?}"

command -v mkfs.fat >/dev/null || { echo "mk-iso: 需要 mkfs.fat（dosfstools）" >&2; exit 1; }
command -v mcopy >/dev/null || { echo "mk-iso: 需要 mcopy（mtools）" >&2; exit 1; }
command -v xorriso >/dev/null || { echo "mk-iso: 需要 xorriso" >&2; exit 1; }

[[ -f "$ZBM_EFI" ]] || { echo "mk-iso: 未找到 ZBM: $ZBM_EFI" >&2; exit 1; }
[[ -f "$KERNEL" ]] || { echo "mk-iso: 未找到内核: $KERNEL" >&2; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

EFIBOOT_IMG="$WORKDIR/efiboot.img"
dd if=/dev/zero of="$EFIBOOT_IMG" bs=1M count=64 status=none
mkfs.fat -F 16 -n ZIRCONZBM "$EFIBOOT_IMG" >/dev/null

mmd -i "$EFIBOOT_IMG" ::EFI ::EFI/BOOT ::BOOT 2>/dev/null || true
mcopy -i "$EFIBOOT_IMG" "$ZBM_EFI" ::EFI/BOOT/BOOTX64.EFI
mcopy -i "$EFIBOOT_IMG" "$KERNEL" ::BOOT/ZKERNEL.ELF

STAGING="$WORKDIR/staging"
mkdir -p "$STAGING"
cp -f "$EFIBOOT_IMG" "$STAGING/efiboot.img"

# efiboot.img 必须位于 xorriso 源目录内，-e 为相对该目录的路径
xorriso -as mkisofs -quiet -o "$ISO" \
  -V ZIRCONOSLUNA \
  -R -J \
  -eltorito-alt-boot \
  -e efiboot.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  "$STAGING"

echo "Created $ISO (ZirconOS Boot Manager UEFI)"
