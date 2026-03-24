#!/usr/bin/env bash
# 探测当前 Zig 能否为各架构生成 UEFI PE/COFF（不写仓库产物）。
set -euo pipefail
ZIG="${ZIG:-zig}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/m.zig" <<'EOF'
const uefi = @import("std").os.uefi;
pub fn main() noreturn {
    _ = uefi.system_table;
    while (true) {}
}
EOF

probe() {
  local triple="$1"
  echo -n "target $triple ... "
  if "$ZIG" build-exe "$TMP/m.zig" -target "$triple" -OReleaseSmall -fstrip 2>/dev/null; then
    echo "ok"
  else
    echo "fail (e.g. UnsupportedCoffArchitecture)"
  fi
  rm -f m m.exe *.efi 2>/dev/null || true
}

cd "$TMP"
echo "Zig: $($ZIG version)"
probe "x86_64-uefi-msvc"
probe "aarch64-uefi-msvc"
probe "riscv64-uefi-msvc"
probe "loongarch64-uefi-msvc"
