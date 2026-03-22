//! 与 ZirconOS `user32` / Shell 转发层之间的 **事件参数约定**（LP64 / LLP64 宿主）。
//!
//! `ShellEvent` 的 `param1` / `param2` 与 Win32 消息中的 `WPARAM`/`LPARAM` 形状类似：在 64 位宿主上，
//! 窗口句柄等 64 位值可能拆成 **低 32 位**（`param1`）与 **高 32 位**（`param2`）。纯 32 位句柄场景下
//! `param2` 传 `0` 即可。

const std = @import("std");

/// 由 `param1`（低）与 `param2`（高）拼出 64 位 HWND/句柄。
pub fn hwndFromParams(param1: i32, param2: i32) u64 {
    const lo = @as(u32, @bitCast(param1));
    const hi = @as(u32, @bitCast(param2));
    return @as(u64, lo) | (@as(u64, hi) << 32);
}

test "hwndFromParams low 32 only" {
    const h = hwndFromParams(-1, 0);
    try std.testing.expectEqual(@as(u64, 0xFFFF_FFFF), h);
}

test "hwndFromParams 64-bit split" {
    const h = hwndFromParams(@bitCast(@as(i32, @intCast(0x11223344))), @bitCast(@as(i32, @intCast(0x55667788))));
    try std.testing.expectEqual(@as(u64, 0x55667788_11223344), h);
}
