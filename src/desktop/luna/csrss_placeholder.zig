//! CSRSS / 会话子系统占位（NT 中 CSRSS 与 Win32 子系统交互；本仓库单进程 Shell 尚未拆分）。
//!
//! 未来：Shell 进程、`winsrv`、硬错误弹窗等边界见 [DESKTOP_MANAGER_NT52_CN.md](../../../docs/DESKTOP_MANAGER_NT52_CN.md)。

/// 编译期锚点，避免空模块被优化掉时可由构建脚本引用。
pub const csrss_session_placeholder: u32 = 0x43535253; // 'CSRSS'

pub fn noteBoundaries() void {
    _ = csrss_session_placeholder;
}
