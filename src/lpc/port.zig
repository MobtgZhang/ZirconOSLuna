//! LPC（Local Procedure Call）端口消息结构桩。
//! 用户态与 csrss 等通信。见 arch_doc.md 第五节。

const std = @import("std");

pub const PORT_MESSAGE = struct {
    /// 数据长度
    data_length: u16 = 0,
    total_length: u16 = 0,
    _reserved: [16]u8 = [_]u8{0} ** 16,
};

pub const LPC_TYPE = enum(u8) {
    connection = 0,
    request = 1,
};

test "port message" {
    const m: PORT_MESSAGE = .{};
    try std.testing.expect(@sizeOf(PORT_MESSAGE) >= 20);
    _ = m;
}
