# ReactOS 代码只读对照笔记（本仓库实现边界）

本文件满足「对照 [ReactOS](https://github.com/reactos/reactos) 引导与 Phase0 思路、**不抄代码**」的工程备忘；实现均在 ZirconOSLuna 中自写（Zig / 汇编）。

## 建议阅读顺序（目录级）

| ReactOS 区域 | 对照目的 |
|--------------|----------|
| `boot/`、`boot/freeldr` | 固件到内核的**阶段划分**（与本文档 Multiboot2 + ZBM 不同，仅理解「先准备环境、再交控制权」） |
| `ntoskrnl/` 初始化注释 | **Phase0 / Phase1** 语义：串口、陷阱、内存描述符等与 `src/kernel/init.zig` 的**顺序类比**，非 API 兼容 |
| `hal/` | 硬件抽象边界；本仓库内核 HAL 仅为 **串口、VGA 文本、帧缓冲绘制**，不对应 ReactOS 完整 HAL |
| `win32ss/` | **窗口站 / 桌面**复杂度说明；Luna 宿主实现与内核 `gui/luna_desktop.zig` **不**尝试复刻 win32k |

## 许可证提醒

ReactOS 以 **GPL-2.0** 为主；阅读架构与注释可以，**禁止**大段复制其源码进入本仓库闭源或混用许可不明的衍生作品。本项目的 Multiboot2、GOP、页表与桌面逻辑均为独立实现。

## 与本仓库的对应关系（概念）

- **UEFI + ZBM**：等价于「自有引导器把 GOP 与 mmap 封进 Multiboot2」，**不是** ReactOS 当前主线引导链的逐行替代。
- **内核 `luna` 桌面**：单线程轮询 + 帧缓冲合成，类比的是「Shell 主循环」思想，**不是** `user32` 消息泵或 GDI 驱动栈。
