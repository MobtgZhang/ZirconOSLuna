# 内核架构完善规划

本文定义 **ZirconOSLuna 内核架构层** 的目标与分阶段交付，并与仓库内 **已实现文件** 保持同步。  
**定位**：本仓库 **不** 实现完整 `ntoskrnl` 或真实调度器，但提供 **类型 / 常量 / 接口规范** 与 **最小可引导 x86-64 内核**，使文档与代码可对照，并便于未来独立内核工程复用契约。

参考：`ideas/arch_doc.md`、`docs/NT52_KERNEL_ARCH_CN.md`。

---

## 一、现状（与代码同步）

### 1.1 已实现（规范桩 + 部分可运行路径）

| 目录 / 文件 | 内容 |
|-------------|------|
| `arch/abi.zig` | LLP64、指针宽度 |
| `arch/x86_64/paging.zig` | 4 级页表索引与常见 PTE 标志位（规范向） |
| `hal/framebuffer.zig` | 帧缓冲表面契约 |
| `hal/timer.zig`、`hal/irq.zig` | 时钟与 IRQ 线号等占位常量 |
| `drivers/video/display_manager.zig` | 脏区与 present（用户态呈现管线） |
| `kernel/nt52/spec.zig` | NT 5.2 版本号、构建号、8 TB 用户空间提示等 |
| `kernel/entry.zig` + `boot/entry.S` | Multiboot2 最小内核入口（验证引导链，非 NT 引导器） |
| `ke/irql.zig`、`ke/sync.zig`、`ke/dpc.zig` | IRQL、同步对象、DPC 类型桩 |
| `mm/va_layout.zig`、`mm/pages.zig` | VA 布局常量、页大小枚举 |
| `ob/types.zig`、`ob/handle.zig` | 对象类型、句柄与命名空间路径常量 |
| `ps/ids.zig`、`ps/state.zig` | PID/TID、进程/线程状态枚举 |
| `se/sid.zig`、`se/access.zig` | SID 桩、访问掩码与通用访问位 |
| `io/irp.zig` | IRP 桩与 `IRP_MJ_*` 主功能码枚举 |
| `lpc/port.zig` | 端口消息与 LPC 类型常量 |
| `loader/pe.zig` | PE 魔数与基础常量 |
| `config/`、`rtl/`、`libs/win32/` | 配置、日志、Win32 表面约定 |
| `root.zig` | 导出上述模块供依赖方引用 |

### 1.2 仍偏「占位 / 可扩展」

| 区域 | 说明 |
|------|------|
| `fs/` | 可为 VFS 挂载点、结点类型等增加 **仅常量级** 扩展 |
| `servers/` | csrss 等服务边界仍以 README 说明为主 |
| **真实 KE/MM 行为** | 调度、工作集、对象引用计数等 **不在** 本仓库实现范围内 |

---

## 二、阶段划分（历史规划，已基本落地）

下列 Phase 为最初里程碑；当前仓库 **已完成** Phase 1–10 的「规范文件」部分，Phase 11 为 **持续维护**（文档与导出一致性）。

| Phase | 主题 | 落地文件（示例） |
|-------|------|------------------|
| 1 | KE | `ke/irql.zig`、`ke/sync.zig`、`ke/dpc.zig` |
| 2 | MM | `mm/va_layout.zig`、`mm/pages.zig` |
| 3 | OB | `ob/types.zig`、`ob/handle.zig` |
| 4 | PS | `ps/ids.zig`、`ps/state.zig` |
| 5 | SE | `se/sid.zig`、`se/access.zig` |
| 6 | IO | `io/irp.zig` |
| 7 | LPC | `lpc/port.zig` |
| 8 | arch/x86_64 | `arch/x86_64/paging.zig` |
| 9 | HAL 扩展 | `hal/timer.zig`、`hal/irq.zig` |
| 10 | Loader | `loader/pe.zig` |
| 11 | 集成与文档 | `root.zig` 导出；本文与 `KERNEL_AND_STACK_CN.md`、`REPOSITORY_LAYOUT_CN.md` 同步更新 |

---

## 三、交付物原则（保持不变）

- 规范层 `.zig` 以 **类型与常量** 为主，避免在本仓库内实现完整调度、分页遍历或驱动加载。
- 新增常量时优先 **注明出处**（公开文档、本书章节或本仓库 `ideas/arch_doc.md`）。
- `zig build test` 应能通过各模块内 `test` 块，防止常量与文档漂移。

---

## 四、与 `ideas/arch_doc.md` 的对应

| arch_doc 章节 | 主要落地 |
|---------------|----------|
| 处理器架构 | `arch/x86_64/paging.zig`、`arch/abi.zig` |
| 内存管理 | `mm/va_layout.zig`、`mm/pages.zig`、`arch/x86_64/paging.zig` |
| WOW64 | `kernel/nt52/spec.zig`、`libs/win32/` |
| 执行体组件 | `ke/`、`ob/`、`ps/`、`mm/`、`io/`、`lpc/`、`se/`（桩） |
| 驱动与安全 | `io/`、`se/`、`kernel/nt52/` + `docs/NT52_KERNEL_ARCH_CN.md` |
