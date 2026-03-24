//! Winlogon `SessionState` 与 Shell `ShellState` 显式映射（NT 5.2 会话管线占位）。

const winlogon = @import("winlogon.zig");
const shell_mod = @import("shell.zig");

/// 将 winlogon 当前会话状态同步到 Shell（Shell 已 `start` 时生效）。
pub fn syncShellStateFromWinlogon() void {
    const ss = winlogon.getSessionState();
    if (shellStateForSession(ss)) |st| {
        shell_mod.setShellStateIfInitialized(st);
    }
}

/// 登录会话状态 → 资源管理器壳状态（无对应时返回 null）。
pub fn shellStateForSession(s: winlogon.SessionState) ?shell_mod.ShellState {
    return switch (s) {
        .no_session, .welcome_screen, .credentials_prompt, .authenticating => .login_screen,
        .loading_profile => .loading_desktop,
        .logged_in => .desktop_active,
        .locking => .locking,
        .locked => .locked,
        .unlocking => .locked,
        .logging_off => .logging_off,
        .shutting_down => .shutting_down,
    };
}

test "session to shell mapping logged in" {
    try @import("std").testing.expectEqual(
        shell_mod.ShellState.desktop_active,
        shellStateForSession(.logged_in).?,
    );
}
