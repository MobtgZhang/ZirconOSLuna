# ob — Object Manager（本仓库边界）

完整系统中：**对象类型、句柄表、命名空间**。

**本仓库不实现** 对象管理器。窗口句柄在 Shell 层用 `u64` 表示（见 `desktop/luna/host_abi.zig`），与宿主 user32 句柄对齐。
