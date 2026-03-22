# ke — Kernel Executive（本仓库边界）

完整系统中：**调度、IRQL、DPC、APC、定时器、互斥** 等。

**本仓库不实现** 内核调度器。Shell 使用的「时钟」由宿主注入 `ShellEvent.timer_tick` 或等价消息；  
若需对照，见 `docs/KERNEL_AND_STACK_CN.md` 中 KE 与 Shell 的关系。
