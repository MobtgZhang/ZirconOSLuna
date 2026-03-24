const std = @import("std");
const uefi = std.os.uefi;
const mb2 = @import("mb2.zig");
const zbm_config = @import("zbm_config");

fn pickGopMode(gop: *uefi.protocol.GraphicsOutput, want_w: u32, want_h: u32) u32 {
    var best: u32 = gop.mode.mode;
    var best_score: u64 = std.math.maxInt(u64);
    var i: u32 = 0;
    while (i < gop.mode.max_mode) : (i += 1) {
        const info = gop.queryMode(i) catch continue;
        switch (info.pixel_format) {
            .red_green_blue_reserved_8_bit_per_color,
            .blue_green_red_reserved_8_bit_per_color,
            => {},
            else => continue,
        }
        if (info.horizontal_resolution < 640 or info.vertical_resolution < 480) continue;
        const dw = @abs(@as(i64, @intCast(info.horizontal_resolution)) - @as(i64, @intCast(want_w)));
        const dh = @abs(@as(i64, @intCast(info.vertical_resolution)) - @as(i64, @intCast(want_h)));
        const score = @as(u64, @intCast(dw * dw + dh * dh));
        if (score < best_score) {
            best_score = score;
            best = i;
        }
    }
    return best;
}

/// 设置显示模式并返回 GOP 指针（供菜单 Blt）；失败返回 null。
pub fn initGopForMenu(bs: *uefi.tables.BootServices) ?*uefi.protocol.GraphicsOutput {
    const gop_maybe = bs.locateProtocol(uefi.protocol.GraphicsOutput, null) catch return null;
    const gop: *uefi.protocol.GraphicsOutput = gop_maybe orelse return null;
    const mid = pickGopMode(gop, zbm_config.fb_width, zbm_config.fb_height);
    gop.setMode(mid) catch return null;
    return gop;
}

pub fn framebufferRgbFromGop(gop: *uefi.protocol.GraphicsOutput) ?mb2.FramebufferRgb {
    const mode = gop.mode.*;
    const info = mode.info.*;
    const bpp: u8 = switch (info.pixel_format) {
        .red_green_blue_reserved_8_bit_per_color,
        .blue_green_red_reserved_8_bit_per_color,
        => 32,
        else => return null,
    };
    const pitch: u32 = info.pixels_per_scan_line * @as(u32, @intCast(bpp / 8));
    return switch (info.pixel_format) {
        .blue_green_red_reserved_8_bit_per_color => mb2.FramebufferRgb{
            .addr = mode.frame_buffer_base,
            .pitch = pitch,
            .width = info.horizontal_resolution,
            .height = info.vertical_resolution,
            .mem_size = mode.frame_buffer_size,
            .bpp = bpp,
            .red_field_position = 16,
            .red_mask_size = 8,
            .green_field_position = 8,
            .green_mask_size = 8,
            .blue_field_position = 0,
            .blue_mask_size = 8,
        },
        .red_green_blue_reserved_8_bit_per_color => mb2.FramebufferRgb{
            .addr = mode.frame_buffer_base,
            .pitch = pitch,
            .width = info.horizontal_resolution,
            .height = info.vertical_resolution,
            .mem_size = mode.frame_buffer_size,
            .bpp = bpp,
            .red_field_position = 0,
            .red_mask_size = 8,
            .green_field_position = 8,
            .green_mask_size = 8,
            .blue_field_position = 16,
            .blue_mask_size = 8,
        },
        else => null,
    };
}
