# arch/x86_64 — AMD64 分页与长模式

完整内核中：Multiboot2、页表建立、IDT、syscall 等。

本仓库仅提供 **4 级页表索引位域与页表项标志** 常量（见 `paging.zig`），**无** 汇编或引导代码。
