# scripts

| 脚本 | 说明 |
|------|------|
| `gen_luna_resources.py` | 程序化生成 `src/desktop/luna/resources/` 下 Luna 主题 PNG，并写出 `src/kernel/gui/data/*.rgba`（桌面图标、`cursor_arrow.rgba`、`wallpaper_bliss_320x180.rgba`）供内核 `@embedFile`；依赖 Python3 + Pillow |
| `fetch-resources.sh` | 从网络下载壁纸等资源至 `src/desktop/luna/resources/`（由 `make fetch-resources` 调用） |
| `fetch-ovmf.sh` | 从 [edk2-nightly](https://retrage.github.io/edk2-nightly/) 下载 `RELEASEX64_OVMF_{CODE,VARS}.fd` 至 `firmware/ovmf/`（`make fetch-ovmf`；UEFI+QEMU 用） |
| `mk-iso.sh` | `mk-iso.sh <BOOTX64.efi> <out.iso> <kernel_elf>`；写入 `ZKERNEL.ELF` / `ZKERNEL_X64.ELF` 与 `boot/conf/zbm.ini`；可选追加多对 `<src> <dst>` 做 mcopy |
| `run-qemu.sh` | 由 `zig build run-kernel` 调用；UEFI 需 OVMF 文件存在 |
| `zbm-uefi-probe.sh` | 探测 Zig 能否链接各 `*-uefi-msvc`（COFF）；`zig build zbm-uefi-probe` |
