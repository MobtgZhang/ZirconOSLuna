# lpc — IPC（本仓库边界）

完整系统中：**LPC/ALPC 端口** 用于子系统与 csrss 等通信。

**本仓库不实现** IPC。Shell 事件由宿主直接调用 `handleShellEvent` 注入。
