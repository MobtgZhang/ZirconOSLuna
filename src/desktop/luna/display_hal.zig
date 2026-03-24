//! 显示呈现抽象：宿主 `present` 与将来内核 `fb_map` 可各实现一套 vtable。

pub const PresentFn = *const fn (ctx: *anyopaque, pixels: []const u8, width: u32, height: u32) void;

pub const DisplayHal = struct {
    ctx: *anyopaque,
    present: PresentFn,

    pub fn noopPresent(ctx: *anyopaque, pixels: []const u8, width: u32, height: u32) void {
        _ = .{ ctx, pixels, width, height };
    }
};

var stub_ctx: u8 = 0;

pub fn stubHal() DisplayHal {
    return .{ .ctx = @ptrCast(&stub_ctx), .present = DisplayHal.noopPresent };
}
