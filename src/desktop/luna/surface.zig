//! RGBA8888 top-down framebuffer for software compositing (host-independent).

const std = @import("std");
const theme = @import("theme.zig");
const font8 = @import("font8.zig");

pub const RgbaSurface = struct {
    width: u32,
    height: u32,
    stride: u32,
    pixels: []u8,

    pub fn init(pixels: []u8, width: u32, height: u32) RgbaSurface {
        return .{
            .width = width,
            .height = height,
            .stride = width * 4,
            .pixels = pixels,
        };
    }

    pub fn pixelIndex(self: *const RgbaSurface, x: u32, y: u32) ?usize {
        if (x >= self.width or y >= self.height) return null;
        return @as(usize, y) * @as(usize, self.stride) + @as(usize, x) * 4;
    }

    pub fn putPixel(self: *RgbaSurface, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        const o = self.pixelIndex(x, y) orelse return;
        const p = self.pixels[o .. o + 4];
        if (a == 255) {
            p[0] = r;
            p[1] = g;
            p[2] = b;
            p[3] = 255;
            return;
        }
        if (a == 0) return;
        const inv: u32 = 255 - a;
        p[0] = @intCast((@as(u32, r) * a + @as(u32, p[0]) * inv) / 255);
        p[1] = @intCast((@as(u32, g) * a + @as(u32, p[1]) * inv) / 255);
        p[2] = @intCast((@as(u32, b) * a + @as(u32, p[2]) * inv) / 255);
        p[3] = @intCast(@min(255, @as(u32, p[3]) + a));
    }

    pub fn fillRect(self: *RgbaSurface, rx: i32, ry: i32, rw: i32, rh: i32, r: u8, g: u8, b: u8, a: u8) void {
        if (rw <= 0 or rh <= 0) return;
        var y = ry;
        while (y < ry + rh) : (y += 1) {
            if (y < 0 or y >= @as(i32, @intCast(self.height))) continue;
            var x = rx;
            while (x < rx + rw) : (x += 1) {
                if (x < 0 or x >= @as(i32, @intCast(self.width))) continue;
                self.putPixel(@intCast(x), @intCast(y), r, g, b, a);
            }
        }
    }

    pub fn fillRectColorRef(self: *RgbaSurface, rx: i32, ry: i32, rw: i32, rh: i32, cref: theme.COLORREF, a: u8) void {
        self.fillRect(rx, ry, rw, rh, theme.getRValue(cref), theme.getGValue(cref), theme.getBValue(cref), a);
    }

    /// 8×8 字体（仅含 `font8.glyph` 支持的字符）。
    pub fn drawText8(self: *RgbaSurface, x: i32, y: i32, text: []const u8, cref: theme.COLORREF) void {
        const r = theme.getRValue(cref);
        const g = theme.getGValue(cref);
        const b = theme.getBValue(cref);
        var cx = x;
        for (text) |ch| {
            const oc = if (ch >= 'a' and ch <= 'z') ch - 32 else ch;
            const gl = font8.glyph(oc) orelse continue;
            var row: u32 = 0;
            while (row < 8) : (row += 1) {
                var col: u32 = 0;
                while (col < 8) : (col += 1) {
                    if ((gl[row] >> @intCast(7 - col)) & 1 != 0) {
                        const px = cx + @as(i32, @intCast(col));
                        const py = y + @as(i32, @intCast(row));
                        if (px >= 0 and py >= 0) {
                            self.putPixel(@intCast(px), @intCast(py), r, g, b, 255);
                        }
                    }
                }
            }
            cx += 9;
        }
    }

    pub fn fillRectGradientV(
        self: *RgbaSurface,
        rx: i32,
        ry: i32,
        rw: i32,
        rh: i32,
        top: theme.COLORREF,
        bot: theme.COLORREF,
    ) void {
        if (rw <= 0 or rh <= 0) return;
        const tr = theme.getRValue(top);
        const tg = theme.getGValue(top);
        const tb = theme.getBValue(top);
        const br = theme.getRValue(bot);
        const bg = theme.getGValue(bot);
        const bb = theme.getBValue(bot);
        var y = ry;
        while (y < ry + rh) : (y += 1) {
            if (y < 0 or y >= @as(i32, @intCast(self.height))) continue;
            const t: u32 = @intCast(y - ry);
            const den: u32 = @intCast(@max(rh - 1, 1));
            const rr: u8 = @intCast((@as(u32, tr) * (den - t) + @as(u32, br) * t) / den);
            const rg: u8 = @intCast((@as(u32, tg) * (den - t) + @as(u32, bg) * t) / den);
            const rb: u8 = @intCast((@as(u32, tb) * (den - t) + @as(u32, bb) * t) / den);
            var x = rx;
            while (x < rx + rw) : (x += 1) {
                if (x < 0 or x >= @as(i32, @intCast(self.width))) continue;
                self.putPixel(@intCast(x), @intCast(y), rr, rg, rb, 255);
            }
        }
    }

    /// Nearest-neighbor stretch blit with alpha.
    pub fn blitStretch(
        self: *RgbaSurface,
        dst_x: i32,
        dst_y: i32,
        dst_w: i32,
        dst_h: i32,
        src: []const u8,
        src_w: u32,
        src_h: u32,
    ) void {
        if (dst_w <= 0 or dst_h <= 0 or src_w == 0 or src_h == 0) return;
        const sw: i32 = @intCast(src_w);
        const sh: i32 = @intCast(src_h);
        var dy: i32 = 0;
        while (dy < dst_h) : (dy += 1) {
            const py = dst_y + dy;
            if (py < 0 or py >= @as(i32, @intCast(self.height))) continue;
            const sy: u32 = @intCast(@divTrunc(dy * sh, dst_h));
            var dx: i32 = 0;
            while (dx < dst_w) : (dx += 1) {
                const px = dst_x + dx;
                if (px < 0 or px >= @as(i32, @intCast(self.width))) continue;
                const sx: u32 = @intCast(@divTrunc(dx * sw, dst_w));
                const si = (@as(usize, sy) * @as(usize, src_w) + sx) * 4;
                if (si + 4 > src.len) continue;
                const s = src[si .. si + 4];
                self.putPixel(@intCast(px), @intCast(py), s[0], s[1], s[2], s[3]);
            }
        }
    }

    /// Copy source rectangle to dst (dx,dy), clipping to surface.
    pub fn blitCopy(
        self: *RgbaSurface,
        dx: i32,
        dy: i32,
        src: []const u8,
        src_w: u32,
        src_h: u32,
        src_x: u32,
        src_y: u32,
        cw: u32,
        ch: u32,
    ) void {
        var row: u32 = 0;
        while (row < ch) : (row += 1) {
            const sy = src_y + row;
            if (sy >= src_h) break;
            var col: u32 = 0;
            while (col < cw) : (col += 1) {
                const sx = src_x + col;
                if (sx >= src_w) break;
                const px = dx + @as(i32, @intCast(col));
                const py = dy + @as(i32, @intCast(row));
                if (px < 0 or py < 0) continue;
                if (px >= @as(i32, @intCast(self.width)) or py >= @as(i32, @intCast(self.height))) continue;
                const si = (@as(usize, sy) * @as(usize, src_w) + sx) * 4;
                if (si + 4 > src.len) continue;
                const s = src[si .. si + 4];
                self.putPixel(@intCast(px), @intCast(py), s[0], s[1], s[2], s[3]);
            }
        }
    }
};
