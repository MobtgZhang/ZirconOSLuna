//! 同步原语类型桩（KEVENT、KMUTEX、KSEMAPHORE）。
//! 规范结构，不含实现体。见 arch_doc.md 第五节。

const std = @import("std");
const irql = @import("irql.zig");

/// 内核事件对象占位（完整实现需等待队列、IRQL 提升等）。
pub const KEVENT = struct {
    /// 保留：真实实现中为链表/队列
    _reserved: [2]usize = [_]usize{0} ** 2,
};

/// 内核互斥体占位（完整实现需递归计数、拥有者线程等）。
pub const KMUTEX = struct {
    _reserved: [4]usize = [_]usize{0} ** 4,
};

/// 内核信号量占位（完整实现需计数、最大计数）。
pub const KSEMAPHORE = struct {
    _reserved: [3]usize = [_]usize{0} ** 3,
};

pub const EventType = enum(u8) {
    notification = 0,
    synchronization = 1,
};

test "sync structs" {
    const e: KEVENT = .{};
    const m: KMUTEX = .{};
    const s: KSEMAPHORE = .{};
    _ = e;
    _ = m;
    _ = s;
    try std.testing.expect(irql.DISPATCH_LEVEL > irql.PASSIVE_LEVEL);
}
