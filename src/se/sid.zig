//! SID（Security Identifier）结构桩。见 arch_doc.md 第五节安全。

const std = @import("std");

pub const SID = struct {
    revision: u8 = 1,
    sub_authority_count: u8 = 0,
    identifier_authority: [6]u8 = [_]u8{0} ** 6,
    sub_authority: [15]u32 = [_]u32{0} ** 15,
};

pub const SID_IDENTIFIER_AUTHORITY = struct {
    value: [6]u8,
};

pub const SECURITY_NULL_SID_AUTHORITY: SID_IDENTIFIER_AUTHORITY = .{ .value = [_]u8{0} ** 6 };
pub const SECURITY_WORLD_SID_AUTHORITY: SID_IDENTIFIER_AUTHORITY = .{ .value = .{ 0, 0, 0, 0, 0, 1 } };
pub const SECURITY_LOCAL_SID_AUTHORITY: SID_IDENTIFIER_AUTHORITY = .{ .value = .{ 0, 0, 0, 0, 0, 2 } };
pub const SECURITY_NT_AUTHORITY: SID_IDENTIFIER_AUTHORITY = .{ .value = .{ 0, 0, 0, 0, 0, 5 } };

test "sid" {
    const s: SID = .{};
    try std.testing.expect(s.revision == 1);
}
