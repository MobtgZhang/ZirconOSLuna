//! 进程 ID、线程 ID 类型。NT 5.2 x64 下为 32 位或 64 位（依实现）。

const std = @import("std");

pub const PID = u32;
pub const TID = u32;

pub const CLIENT_ID = struct {
    process_id: PID,
    thread_id: TID,
};

pub const INVALID_PID: PID = 0;
pub const SYSTEM_PROCESS_ID: PID = 4;

test "client id" {
    const c: CLIENT_ID = .{ .process_id = 1234, .thread_id = 5678 };
    try std.testing.expect(c.process_id == 1234);
}
