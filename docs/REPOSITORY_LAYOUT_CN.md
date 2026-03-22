# 仓库目录与「完整 NT 型工程」对照

下列 **`src/`** 布局刻意与常见 **NT 风格内核工程** 的顶层目录同名。  
**可引导内核**：`boot/entry.S` + `src/kernel/entry.zig`，Multiboot2 + GRUB ISO，`make kernel` / `make run-kernel`。  
其余目录以各 `README.md` 为准。

```
src/
├── root.zig                 # **Zig 库模块根**（`build.zig` 中 `ZirconOSLuna` 入口）
├── main.zig                 # 本包 CLI / 自测入口（非 OS 内核入口）
├── config/                  # 主题与 Shell 默认配置（用户态配置，非内核 conf 解析器全集）
├── arch/                    # 宿主 ABI / 指针宽度约定（非引导与分页）
├── hal/                     # 呈现层「硬件抽象」：帧缓冲表面（非内核 HAL 全集）
├── drivers/
│   └── video/               # 显示管线侧接口：脏区、合成提交（非 KMD 驱动）
├── ke/                      # 占位：说明与 KE 的边界；本仓库不实现调度器
├── mm/                      # 占位：说明与 MM 的边界
├── ob/                      # 占位：句柄语义说明
├── ps/                      # 占位：会话/进程边界说明
├── se/                      # 占位：登录与令牌边界说明
├── io/                      # 占位：与 IRP/设备栈的边界
├── lpc/                     # 占位：与消息/IPC 的边界
├── rtl/                     # 轻量运行时辅助（如日志桩）
├── fs/                      # 占位：资源文件路径与 VFS 边界
├── loader/                  # 占位：PE 资源加载边界
├── libs/
│   └── win32/               # Win32 侧类型与 HWND 约定（非完整 SDK）
├── kernel/
│   ├── entry.zig            # 可引导内核入口（VGA + 串口，x86-64 freestanding）
│   └── nt52/                # NT 5.2 规范常量（非 ntoskrnl 实现；见 spec.zig）
├── servers/                 # 占位：与系统服务进程的边界
└── desktop/
    └── luna/                # Luna Shell/主题/控件/渲染协调（本仓库主体实现）
```

## 与「完整 NT 型 OS 工程树」的关系

常见完整 OS 仓库会有 `main.zig` 内核入口、`arch/x86_64`、`hal`、`drivers/video`、`ke`、`mm` 等。  
**本仓库** 以 **Shell/主题库** 为主体，同时包含 **最小可引导 x86-64 内核**（`boot/`、`link/`、`src/kernel/entry.zig`），用于验证 NT 5.2 架构规范；在 **同名顶层目录** 下提供 **边界说明 + 少量用户态可编译接口**。

若你另有独立内核工程，可将本仓库以 **子模块或路径依赖** 接入任意路径；**无**强制目录名要求。

XP x64 / NT 5.2 背景与论坛资料见 [REFERENCES_CN.md](REFERENCES_CN.md)、[NT52_KERNEL_ARCH_CN.md](NT52_KERNEL_ARCH_CN.md)。

## 可引导内核目录（`src/kernel/` + `boot/`）

| 路径 | 角色 |
|------|------|
| `boot/entry.S` | Multiboot2、**512MiB 恒等映射（2MiB 大页）**、GDT、栈、调用 `kernel_main` |
| `boot/isr_x86_64.S` | CPU 向量 0–31 与占位 `isr_stub_reserved` |
| `boot/idt_load.S` | `lidt`（读取 Zig 导出的 `kernel_idt_descriptor`） |
| `src/kernel/entry.zig` | `kernel_main`：Phase0 → VGA 提示 |
| `src/kernel/init.zig` | Phase0：HAL 串口、Multiboot2 摘要、PMM、IDT |
| `src/kernel/hal/` | `port.zig`、`serial.zig`（COM1） |
| `src/kernel/mm/` | `mboot2.zig`、`pmm.zig`（mmap 或线性后备池） |
| `src/kernel/arch/idt.zig` | 256 项 IDT 与门描述符 |
| `src/kernel/ke/trap.zig` | `exceptionDispatch`（故障时串口停机） |

运行 ISO：`zig build run-kernel` 默认 **弹出 QEMU 图形窗口**（VGA 文本），内核 **COM1** 同时接到 **`-serial stdio`**（终端里可见 `[HAL]` 等日志）。无图形时用 `-Dqemu-nographic=true` 或 `make QEMU_NOGRAPHIC=1 run`。修改内核后需 **`zig build kernel` 并重建 ISO**。
