# 多内核架构与 UEFI 引导说明

## ZBM 启动菜单（`\\BOOT\\zbm.ini`）

- ISO 构建时复制 [boot/conf/zbm.ini](boot/conf/zbm.ini) 至 `\BOOT\zbm.ini`；含 `timeout`、`default`、`gfx_menu` 与 `entryN_title` / `entryN_kernel`。
- 可选 **`profile=`**（或 `platform_profile=`）：在标题下打印「Profile: …」，标明 LoongArch 等**内核目标**，避免与 **BOOTX64.EFI（x86_64）** 混淆。
- 可选 **`brief_menu=1`**：隐藏「本 .efi 为 x86_64」两行说明（仍会拒绝非 x86_64 内核 ELF，并打印 `e_machine` 错误）。
- x86_64 下 ZBM 使用 ConOut 文本菜单 + 可选 GOP Blt 高亮条；选中的 `kernel` 路径再经 Multiboot2 加载。
- `zig build iso` 将同一 x86_64 内核复制为 `ZKERNEL.ELF` 与 `ZKERNEL_X64.ELF`；其它架构 ELF 可通过 `mk-iso.sh` 额外成对参数追加（见脚本注释）。

## `zig build zbm-aarch64`

生成 **aarch64** 的 `BOOTAA64.EFI`（占位：仅 ConOut 提示）。当前 Zig 0.15 对 **riscv64 / loongarch64 的 UEFI COFF** 会报 `UnsupportedCoffArchitecture`，故未在 `build.zig` 中生成对应 `.efi`；需在工具链支持后再加。

运行 `zig build zbm-uefi-probe`（或 `bash scripts/zbm-uefi-probe.sh`）可本地确认各 UEFI triple 是否可链接。

LoongArch 真机/固件路径、gnu-efi 备选与分阶段 To-do 见 [LOONGARCH_UEFI_CN.md](LOONGARCH_UEFI_CN.md)。

## `KERNEL_ARCH`（`zig build -Dkernel-arch=…`）

| 取值 | 内核 bring-up | ZBM（同 ISA `.efi`） | 典型 QEMU |
|------|---------------|----------------------|-----------|
| `x86_64` | Multiboot2 + 跳板，可启动 | `BOOTX64.EFI` | `qemu-system-x86_64` + OVMF |
| `aarch64` | 最小桩（停机/串口 WIP） | `BOOTAA64.EFI` | `qemu-system-aarch64 -machine virt` + EDK2 |
| `riscv64` | 最小桩 | `BOOTRISCV64.EFI`（视固件约定） | `qemu-system-riscv64` |
| `loongarch64` | 最小桩；**路线默认文档架构** | `BOOTLOONGARCH64.EFI`（EDK2 约定） | `qemu-system-loongarch64` |

UEFI 要求：**固件 CPU 与 `.efi` 架构一致**；一份 `BOOTX64.EFI` 不能启动 LoongArch 内核。ISO 上可同时放置多个内核 ELF 与一份 `zbm.ini`，但**实际执行的 ZBM 必须是当前机器架构**。

## `build.conf` 中 `KERNEL_ARCH = loongarch64`

与 `zig build` 默认 `-Dkernel-arch=loongarch64` 一致。在 **x86_64 PC QEMU + OVMF** 上跑现有 ZBM/内核请显式改为：

```bash
make kernel KERNEL_ARCH=x86_64
# 或
zig build kernel -Dkernel-arch=x86_64
```

## 宿主 `DESKTOP` 与内核 `KERNEL_DESKTOP`

- **DESKTOP / HOST_DESKTOP**：本机 `zig build run` 的 Luna Shell（有操作系统）。
- **KERNEL_DESKTOP**：来宾内核内 `cmd` / `luna`（freestanding）。

二者**不重复**，仅命名易混；见 [KERNEL_AND_STACK_CN.md](KERNEL_AND_STACK_CN.md)。
