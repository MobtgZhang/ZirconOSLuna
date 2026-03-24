//! Render coordinator — dirty regions, frame sequencing, and layer hints for the
//! host framebuffer / GDI bridge. Single place to merge invalidation from desktop,
//! taskbar, shell windows, and overlays (double-buffer friendly).
//!
//! **帧率**：宿主应在事件循环中于 `presentComplete` 之间加入最小间隔（例如 16ms）以限制 CPU；
//! 本模块不依赖 OS 定时器，由调用方（如 SDL/Win32 主循环）实现。

const std = @import("std");

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn intersects(a: Rect, b: Rect) bool {
        return a.x < b.x + b.w and a.x + a.w > b.x and
            a.y < b.y + b.h and a.y + a.h > b.y;
    }

    pub fn unionBounds(a: Rect, b: Rect) Rect {
        const ax2 = a.x + a.w;
        const ay2 = a.y + a.h;
        const bx2 = b.x + b.w;
        const by2 = b.y + b.h;
        const x1 = @min(a.x, b.x);
        const y1 = @min(a.y, b.y);
        const x2 = @max(ax2, bx2);
        const y2 = @max(ay2, by2);
        return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }
};

pub const RenderLayer = enum(u8) {
    desktop = 0,
    taskbar = 1,
    shell_window = 2,
    overlay = 3,
    cursor = 4,
};

pub const MAX_DIRTY_RECTS: usize = 48;

var screen_w: i32 = 800;
var screen_h: i32 = 600;
var full_invalidate: bool = false;
var dirty_count: usize = 0;
var dirty_rects: [MAX_DIRTY_RECTS]Rect = undefined;
var frame_seq: u64 = 0;
var layer_mask: u8 = 0xFF;

pub fn init(width: i32, height: i32) void {
    screen_w = width;
    screen_h = height;
    full_invalidate = true;
    dirty_count = 0;
    frame_seq = 0;
    layer_mask = 0xFF;
}

pub fn setScreenSize(width: i32, height: i32) void {
    screen_w = width;
    screen_h = height;
    invalidateFull();
}

pub fn getScreenSize() struct { w: i32, h: i32 } {
    return .{ .w = screen_w, .h = screen_h };
}

pub fn getFrameSequence() u64 {
    return frame_seq;
}

/// Hint: host may skip layers (e.g. overlay only). Default = all layers.
pub fn setLayerMask(mask: u8) void {
    layer_mask = mask;
}

pub fn getLayerMask() u8 {
    return layer_mask;
}

fn clipToScreen(r: Rect) Rect {
    const sw = screen_w;
    const sh = screen_h;
    const x = @max(r.x, 0);
    const y = @max(r.y, 0);
    const x2 = @min(r.x + r.w, sw);
    const y2 = @min(r.y + r.h, sh);
    return .{
        .x = x,
        .y = y,
        .w = @max(0, x2 - x),
        .h = @max(0, y2 - y),
    };
}

pub fn invalidateFull() void {
    full_invalidate = true;
    dirty_count = 0;
}

pub fn invalidateRect(r: Rect) void {
    if (full_invalidate) return;
    const c = clipToScreen(r);
    if (c.w <= 0 or c.h <= 0) return;
    if (dirty_count >= MAX_DIRTY_RECTS) {
        full_invalidate = true;
        dirty_count = 0;
        return;
    }
    dirty_rects[dirty_count] = c;
    dirty_count += 1;
}

pub fn invalidateDesktopArea() void {
    invalidateRect(.{ .x = 0, .y = 0, .w = screen_w, .h = screen_h });
}

/// 按合成层失效近似矩形（与 [compositor.zig](compositor.zig) `layer_order` 一致）。
pub fn invalidateLayer(layer: RenderLayer) void {
    const tb_h: i32 = @import("theme.zig").TASKBAR_HEIGHT;
    switch (layer) {
        .desktop => invalidateRect(.{ .x = 0, .y = 0, .w = screen_w, .h = screen_h - tb_h }),
        .taskbar => invalidateRect(.{ .x = 0, .y = screen_h - tb_h, .w = screen_w, .h = tb_h }),
        .shell_window => invalidateDesktopArea(),
        .overlay => invalidateDesktopArea(),
        .cursor => {
            // 光标层：小矩形占位，实际宿主可传鼠标坐标扩展
            invalidateRect(.{ .x = 0, .y = 0, .w = screen_w, .h = screen_h });
        },
    }
}

pub fn needsRedraw() bool {
    return full_invalidate or dirty_count > 0;
}

pub fn isFullInvalidate() bool {
    return full_invalidate;
}

pub const DirtySnapshot = struct {
    full_screen: bool,
    rects: []const Rect,
};

/// Borrowed view of current dirty state (valid until next `presentComplete` or invalidate).
pub fn snapshotDirty() DirtySnapshot {
    if (full_invalidate) {
        return .{ .full_screen = true, .rects = &.{} };
    }
    return .{ .full_screen = false, .rects = dirty_rects[0..dirty_count] };
}

/// Call after the host has composited / blitted to the display (end of frame).
pub fn presentComplete() void {
    full_invalidate = false;
    dirty_count = 0;
    frame_seq +%= 1;
}

pub fn copyDirtyRects(out: []Rect) usize {
    const n = @min(out.len, dirty_count);
    @memcpy(out[0..n], dirty_rects[0..n]);
    return n;
}

test "dirty region coalesces to full when overflow" {
    init(100, 100);
    var i: i32 = 0;
    while (i < MAX_DIRTY_RECTS + 2) : (i += 1) {
        invalidateRect(.{ .x = i, .y = 0, .w = 1, .h = 1 });
    }
    try std.testing.expect(isFullInvalidate());
}

test "clip negative rect" {
    init(50, 50);
    full_invalidate = false;
    dirty_count = 0;
    invalidateRect(.{ .x = -10, .y = -10, .w = 20, .h = 20 });
    const s = snapshotDirty();
    try std.testing.expect(!s.full_screen);
    try std.testing.expectEqual(@as(usize, 1), s.rects.len);
    try std.testing.expectEqual(@as(i32, 0), s.rects[0].x);
}
