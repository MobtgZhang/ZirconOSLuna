//! Windows NT 5.x 目标与 Win32 头文件契约（供宿主 PE / 兼容子系统对照）。
//!
//! 本库 **不** 实现内核；此处仅固定 **行为与资源分层** 所依据的 Windows 产品线划分，避免「NT5.2」与「XP」混用。
//!
//! ## 产品线与内核版本
//!
//! | 系统 | 内核主版本 | 说明 |
//! |------|------------|------|
//! | Windows XP（32 位） | NT 5.1 | 多数文档中「Windows XP」指此 |
//! | Windows XP Professional x64 | NT 5.2 | 与 Windows Server 2003 代码库同源 |
//! | Windows Server 2003 | NT 5.2 | 与 XP x64 同属「WS03 / 0x0502」API 代 |
//!
//! ## C / SDK 侧目标宏（宿主 PE 编译时）
//!
//! 官方说明见 Microsoft Learn：[Using the Windows Headers](https://learn.microsoft.com/en-us/windows/win32/winprog/using-the-windows-headers)、
//! [Modifying WINVER and _WIN32_WINNT](https://learn.microsoft.com/en-us/cpp/porting/modifying-winver-and-win32-winnt)。
//! 若需 **XP SP2 起** 与 **Server 2003** 共有 API，通常使用 `_WIN32_WINNT` = `0x0502`（`WINVER` 同步）。
//!
//! ## 指针与句柄（64 位 XP / LLP64）
//!
//! 64 位 Windows 使用 LLP64：`long` 仍为 32 位，指针与 `HWND`/`HDC` 等为 64 位。
//! 本 Zig 库中窗口句柄使用 `u64`，与 64 位 Win32 用户态一致；**不得** 将 `HWND` 截断为 `u32`。
//!
//! ## 社区参考（非微软规范）
//!
//! - [MSFN](https://msfn.org/board/) — Windows XP 维护与兼容讨论
//! - [Vogons](https://www.vogons.org/) — 旧版 Windows / 驱动与图形相关讨论

/// `_WIN32_WINNT_WINXP` — 对应 Windows XP 32 位（NT 5.1）类目标。
pub const WIN32_WINNT_WINXP: u16 = 0x0501;

/// `_WIN32_WINNT_WS03` — Windows Server 2003、**Windows XP x64**（NT 5.2）代 API 常用下限。
pub const WIN32_WINNT_WS03: u16 = 0x0502;

/// `NTDDI_WINXPSP3`（示例）：细粒度 NTDDI 见 SdkDdkVer.h；宿主若链接 XP SP3 行为可对照。
pub const NTDDI_WINXPSP3: u32 = 0x05010300;

pub const NtProductLine = enum(u8) {
    /// NT 5.1 — Windows XP 32-bit
    nt51_xp_x86,
    /// NT 5.2 — Windows XP x64 / Windows Server 2003 家族
    nt52_xp_x64_or_ws03,
};

/// Luna 视觉与 comctl32 v6 行为以 **XP + SP2 以后** 与 Server 2003 共有子集为主（即 API 代 `0x0502` 对齐）。
pub const luna_api_generation: u16 = WIN32_WINNT_WS03;
