//! 帧缓冲 / 离屏表面契约 —— 面向宿主或显示服务的「最小 HAL」。
//! 与内核 HAL 无关：仅抽象一块可写的像素存储。

const std = @import("std");

pub const PixelFormat = enum(u8) {
    bgra8888 = 0,
    rgba8888 = 1,
};

/// 由宿主提供：指向某块显存或共享缓冲的视图。
pub const FramebufferSurface = struct {
    pub const VTable = struct {
        /// 宽度、高度、每行字节数、像素格式。
        getLayout: *const fn (ctx: *anyopaque) struct { w: u32, h: u32, stride_bytes: u32, fmt: PixelFormat },
        /// 将脏区标记为已提交（可选，用于双缓冲交换）。
        present: ?*const fn (ctx: *anyopaque) void = null,
    };

    ctx: *anyopaque,
    vtable: VTable,

    pub fn getLayout(self: *const FramebufferSurface) struct { w: u32, h: u32, stride_bytes: u32, fmt: PixelFormat } {
        return self.vtable.getLayout(self.ctx);
    }

    pub fn present(self: *const FramebufferSurface) void {
        if (self.vtable.present) |p| p(self.ctx);
    }
};

var null_ctx_storage: u8 = 0;

/// 占位：宿主未接硬件时，可拒绝或返回零尺寸。
pub fn nullSurface() FramebufferSurface {
    const S = struct {
        fn layout(_: *anyopaque) struct { w: u32, h: u32, stride_bytes: u32, fmt: PixelFormat } {
            return .{ .w = 0, .h = 0, .stride_bytes = 0, .fmt = .bgra8888 };
        }
    };
    return .{
        .ctx = @ptrCast(&null_ctx_storage),
        .vtable = .{ .getLayout = S.layout, .present = null },
    };
}

test "null surface layout" {
    var s = nullSurface();
    const L = s.getLayout();
    try std.testing.expectEqual(@as(u32, 0), L.w);
}
