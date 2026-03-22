//! KDPC（Deferred Procedure Call）— 延迟过程调用类型桩。
//! 完整实现中由 KeInsertQueueDpc 等排入 DPC 队列，在 DISPATCH_LEVEL 执行。

const std = @import("std");

pub const KDPC = struct {
    /// 类型：普通 / 定时器 等
    type: Type = .normal,
    _reserved: [4]usize = [_]usize{0} ** 4,

    pub const Type = enum(u8) {
        normal = 0,
        threaded = 1,
    };
};

test "dpc type" {
    const d: KDPC = .{};
    try std.testing.expect(d.type == .normal);
}
