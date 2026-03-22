# 论坛与公开资料（Windows XP x64 / NT 5.2 / Win32）

本页汇总 **复现或兼容 Windows XP Professional x64（NT 5.2）** 时可用的社区讨论与公开技术资料，**不构成**微软官方规范。动手前请自行核对许可、版权与论坛规则。

---

## 一、开发者论坛与社区（优先）

| 名称 | 链接 | 适用场景 |
|------|------|----------|
| **MSFN — Windows XP 64 Bit Edition** | [msfn.org/board/forum/104-windows-xp-64-bit-edition](https://msfn.org/board/forum/104-windows-xp-64-bit-edition/) | **XP x64 专用版块**：驱动、整合盘、现代硬件兼容、补丁与折腾经验，讨论量集中。 |
| **MSFN — Windows XP** | [msfn.org/board/forum/82-windows-xp](https://msfn.org/board/forum/82-windows-xp/) | 通用 XP（含与 x64 交叉的问题：资源、工具链）。 |
| **OSR — NTDEV / 内核与驱动** | [community.osr.com](https://community.osr.com/) | **内核模式驱动、IRP、调试、WHQL**：与「必须原生 x64 的 KMD」强相关；帖子偏 NT 内核工程实践。 |
| **OSR — The NT Insider（文章归档）** | [osronline.com](https://www.osronline.com/) | 历史技术文章、新闻通讯；适合查旧版 Windows 驱动模型背景。 |
| **OSDev.org 论坛** | [forum.osdev.org](https://forum.osdev.org/) | 自制 OS、长模式/分页/引导等 **通用** 概念；偶有「在 XP x64 上跑实验」类主题。 |
| **VOGONS** | [www.vogons.org](https://www.vogons.org/) | 旧显卡、VESA、虚拟机显示；与 **用户态呈现 / 旧驱动** 相关时有用。 |

**使用建议**：MSFN 偏「系统维护与兼容」；要写 **KMD** 或理解 **IRP/即插即用**，应同时盯 OSR 与微软旧版 DDK/WDK 文档。

---

## 二、微软文档（仍在线或归档）

| 主题 | 链接 |
|------|------|
| 各版本 Windows 的内存上限（含 XP x64 物理内存等） | [Memory Limits for Windows Releases](https://learn.microsoft.com/en-us/windows/win32/memory/memory-limits-for-windows-releases) |
| 64 位 Windows 常见问题（用户/内核地址空间等概述） | [General FAQs About 64-bit Windows（存档）](https://learn.microsoft.com/en-us/previous-versions/msdn10/bb190528(v=msdn.10)) |
| `WINVER` / `_WIN32_WINNT` / `NTDDI_*` 与目标系统 | [Using the Windows Headers](https://learn.microsoft.com/en-us/windows/win32/winprog/using-the-windows-headers) |
| 移植时修改版本宏 | [Modifying WINVER and _WIN32_WINNT](https://learn.microsoft.com/en-us/cpp/porting/modifying-winver-and-win32-winnt) |

> **NT 5.2 注意**：面向 **XP x64 / Server 2003 x64** 时，SDK/DDK 头文件中的目标宏通常对应 **NT 5.2**，与 32 位 XP（NT 5.1）区分；具体宏组合以你使用的 WDK/Platform SDK 版本为准。

---

## 三、开源对照实现（非微软代码，许可为 GPL/LGPL 等）

| 项目 | 链接 | 说明 |
|------|------|------|
| **ReactOS** | [github.com/reactos/reactos](https://github.com/reactos/reactos) | 以 **Windows Server 2003 / NT 5.x** 兼容为目标的完整内核与用户态树（`ntoskrnl/`、`hal/`、`win32ss/` 等）。适合对照 **分层与模块边界**，**不可**直接混用其 C 代码到闭源或不相容许可的工程；贡献前需阅读其法律声明（接触过泄露 Windows 源码者不可贡献）。 |

## 四、书籍与深度文章（非论坛，但常被开发者引用）

| 来源 | 说明 |
|------|------|
| *Windows Internals*（第 4 版覆盖 Windows 2000 / XP / Server 2003） | 虚拟地址空间、内存管理器、I/O、对象管理器等 **体系级** 背景；x64 细节需结合更新资料。 |
| CodeMachine — *X64 Kernel Virtual Address Space* | 对 **x64 内核虚拟地址布局** 有分区域说明（各 Windows 版本间仍有差异，仅作对照）。 |
| Raymond Chen — *The Old New Thing*（博客） | Win32 行为、兼容性与历史决策，**非**内核规范，但有助于理解用户态 API 与 Shell 边界。 |

---

## 五、与本仓库相关的阅读顺序建议

1. 架构总览：`docs/NT52_KERNEL_ARCH_CN.md`、`docs/KERNEL_AND_STACK_CN.md`  
2. 代码与目录对照：`docs/REPOSITORY_LAYOUT_CN.md`、`docs/PLAN_KERNEL_ARCH_CN.md`  
3. 需要 **驱动或内核调试** 时：OSR + 微软内存/头文件文档 + MSFN x64 版块的具体机型经验  

---

## 六、与 [ZirconOSAero](https://github.com/MobtgZhang/ZirconOSAero) 的说明

ZirconOSAero 以 **NT 6.1（Windows 7）** 体验为产品目标；本仓库（ZirconOSLuna）以 **NT 5.2 / Luna** 为对照。二者 **独立**；Makefile 风格可参考，**勿混淆** 内核版本与 API 集。
