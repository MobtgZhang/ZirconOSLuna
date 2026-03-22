//! 宿主进程 ABI 约定（与 64 位 Windows 用户态一致：LLP64）。
//! 非内核引导模块。

/// 指针/句柄在 64 位用户态为 8 字节；与 `HWND`/`HDC` 等宽。
pub const pointer_bits: u8 = 64;

pub const intptr = i64;
pub const uintptr = u64;
