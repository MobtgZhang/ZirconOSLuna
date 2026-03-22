//! 对象管理器：对象类型枚举与命名空间路径常量。
//! 见 arch_doc.md 第五节对象管理器。

const std = @import("std");

pub const ObjectType = enum(u16) {
    unknown = 0,
    device = 1,
    driver = 2,
    directory = 3,
    event = 4,
    event_pair = 5,
    file = 6,
    key = 7,
    keyed_event = 8,
    mutant = 9,
    port = 10,
    process = 11,
    profile = 12,
    section = 13,
    semaphore = 14,
    symbolic_link = 15,
    thread = 16,
    timer = 17,
    token = 18,
    type = 19,
};

pub const NS_DEVICE: []const u8 = "\\Device\\";
pub const NS_DRIVER: []const u8 = "\\Driver\\";
pub const NS_BASE_NAMED: []const u8 = "\\BaseNamedObjects\\";

test "object types" {
    try std.testing.expect(@intFromEnum(ObjectType.process) == 11);
    try std.testing.expect(@intFromEnum(ObjectType.thread) == 16);
}
