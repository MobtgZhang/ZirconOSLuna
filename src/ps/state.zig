//! 进程与线程状态枚举。规范类型，无调度逻辑。

const std = @import("std");

pub const ProcessState = enum(u8) {
    initializing = 0,
    ready = 1,
    running = 2,
    standby = 3,
    terminated = 4,
    waiting = 5,
};

pub const ThreadState = enum(u8) {
    initialized = 0,
    ready = 1,
    running = 2,
    standby = 3,
    terminated = 4,
    waiting = 5,
};

pub const WaitReason = enum(u8) {
    executive = 0,
    free_page = 1,
    page_in = 2,
    pool_allocation = 3,
    delay_execution = 4,
    suspended = 5,
    user_request = 6,
    wr_mutex = 7,
};

test "states" {
    try std.testing.expect(@intFromEnum(ProcessState.terminated) == 4);
}
