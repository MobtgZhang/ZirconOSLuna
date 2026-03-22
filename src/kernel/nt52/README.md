# kernel/nt52 — NT 5.2 规范常量（非 ntoskrnl 实现）

本目录 **不包含** 可引导内核、调度器或 HAL 二进制，仅存放与 **Windows XP x64 / Server 2003（NT 5.2）** 产品线对齐的 **常量与注释**，供：

- `host_abi`（64 位 HWND）与 NT 5.2 x64 用户态一致；
- 文档 `docs/NT52_KERNEL_ARCH_CN.md` 中的架构描述与代码交叉引用。

若需完整微内核/执行体实现，应在 **独立操作系统仓库** 中开发；本仓库定位为 **用户态 Shell/主题库**。
