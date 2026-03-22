//! IRP（I/O Request Packet）结构桩与主功能码。
//! 见 arch_doc.md 第五节 I/O 管理器。

const std = @import("std");
const ob = @import("../ob/handle.zig");

pub const IRP_MJ_CREATE: u8 = 0x00;
pub const IRP_MJ_CLOSE: u8 = 0x02;
pub const IRP_MJ_READ: u8 = 0x03;
pub const IRP_MJ_WRITE: u8 = 0x04;
pub const IRP_MJ_DEVICE_CONTROL: u8 = 0x0E;
pub const IRP_MJ_INTERNAL_DEVICE_CONTROL: u8 = 0x0F;

pub const MajorFunction = enum(u8) {
    create = IRP_MJ_CREATE,
    close = IRP_MJ_CLOSE,
    read = IRP_MJ_READ,
    write = IRP_MJ_WRITE,
    device_control = IRP_MJ_DEVICE_CONTROL,
    internal_device_control = IRP_MJ_INTERNAL_DEVICE_CONTROL,
};

pub const IRP = struct {
    /// 主功能码
    major_function: u8 = 0,
    _reserved: [7]u8 = [_]u8{0} ** 7,
    /// 目标设备对象（占位）
    device: ob.PVOID = null,
};

test "irp" {
    const r: IRP = .{ .major_function = IRP_MJ_READ };
    try std.testing.expect(r.major_function == 0x03);
}
