# NT 5.x 与 Luna 主题目标

本文件说明 **Luna 主题** 所参照的 NT 5.x / Win32 SDK 目标；**不**替代任何具体内核或 csrss 实现文档。全栈分层见仓库根目录 `docs/KERNEL_AND_STACK_CN.md`。

## 内核与产品线

| 系统 | NT 版本 | 备注 |
|------|---------|------|
| Windows XP 32 位 | 5.1 | 常见「XP」指此 |
| Windows XP Professional x64 | 5.2 | 与 Windows Server 2003 同源 |
| Windows Server 2003 | 5.2 | API 代常与 `0x0502` 对齐 |

## Win32 / SDK 宏（宿主 PE 编译）

- [Using the Windows Headers](https://learn.microsoft.com/en-us/windows/win32/winprog/using-the-windows-headers) — `WINVER`、`_WIN32_WINNT`、`NTDDI_VERSION`
- [Modifying WINVER and _WIN32_WINNT](https://learn.microsoft.com/en-us/cpp/porting/modifying-winver-and-win32-winnt) — MSVC 目标系统

Luna 控件与 **comctl32 v6 / uxtheme** 共有行为，实现上按 **API 代 0x0502（WS03 / XP x64 线）** 为下限（见 `nt_target.zig` 中 `luna_api_generation`）。

## 句柄与事件（64 位）

64 位 Windows 为 LLP64：`HWND` 等为 64 位。`shell` 中窗口事件使用 `host_abi.hwndFromParams(param1, param2)`：**低 32 位**在 `param1`，**高 32 位**在 `param2`；仅 32 位句柄时 `param2 = 0`。

## 社区参考（非官方）

- [MSFN](https://msfn.org/board/) — Windows XP 维护与兼容
- Stack Overflow 标签 `winapi`、`windows-xp` — API 行为问答
