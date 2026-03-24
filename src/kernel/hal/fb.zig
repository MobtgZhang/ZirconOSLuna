//! 线性帧缓冲绘制（BGRA 32bpp，与 UEFI GOP / Multiboot2 常见布局一致）。

const mboot2 = @import("../mm/mboot2.zig");

fn colorRefToBgra(cr: u32) u32 {
    const r = cr & 0xFF;
    const g = (cr >> 8) & 0xFF;
    const b = (cr >> 16) & 0xFF;
    return b | (g << 8) | (r << 16) | 0xFF000000;
}

/// Debug 下 `Canvas` 方法体会生成极大栈与安全分支；热路径放在本模块级函数并关闭 runtime safety，避免错误访存 #PF。
fn blendRgbaOntoUnsafe(pixels: [*]volatile u32, idx: usize, sr: u8, sg: u8, sb: u8, sa: u8) void {
    @setRuntimeSafety(false);
    if (sa == 0) return;
    if (sa == 255) {
        pixels[idx] = @as(u32, sb) | (@as(u32, sg) << 8) | (@as(u32, sr) << 16) | 0xFF000000;
        return;
    }
    const dst = pixels[idx];
    const dr = (dst >> 16) & 0xFF;
    const dg = (dst >> 8) & 0xFF;
    const db = dst & 0xFF;
    const inv: u32 = 255 - sa;
    const nr: u8 = @intCast((@as(u32, sr) * sa + @as(u32, dr) * inv) / 255);
    const ng: u8 = @intCast((@as(u32, sg) * sa + @as(u32, dg) * inv) / 255);
    const nb: u8 = @intCast((@as(u32, sb) * sa + @as(u32, db) * inv) / 255);
    pixels[idx] = @as(u32, nb) | (@as(u32, ng) << 8) | (@as(u32, nr) << 16) | 0xFF000000;
}

const BlitRgbaArgs = struct {
    pixels: [*]volatile u32,
    fb_w: u32,
    fb_h: u32,
    words_per_row: u32,
    dx: u32,
    dy: u32,
    src: [*]const u8,
    src_len: usize,
    w: u32,
    h: u32,
};

const BlitRgbaStretchArgs = struct {
    pixels: [*]volatile u32,
    fb_w: u32,
    fb_h: u32,
    words_per_row: u32,
    dx: u32,
    dy: u32,
    dw: u32,
    dh: u32,
    src: [*]const u8,
    src_len: usize,
    sw: u32,
    sh: u32,
};

/// 单指针参数，避免 x86-64 上 >6 标量参数时 Debug 代码的栈参布局与反复 `[rbp+off]` 访存问题。
noinline fn blitRgbaUnsafe(p: *const BlitRgbaArgs) void {
    @setRuntimeSafety(false);
    if (p.w == 0 or p.h == 0) return;
    const need = @as(usize, p.w) * @as(usize, p.h) * 4;
    if (p.src_len < need) return;
    var sy: u32 = 0;
    while (sy < p.h) : (sy += 1) {
        const y = p.dy + sy;
        if (y >= p.fb_h) break;
        var sx: u32 = 0;
        while (sx < p.w) : (sx += 1) {
            const x = p.dx + sx;
            if (x >= p.fb_w) break;
            const si = (@as(usize, sy) * @as(usize, p.w) + @as(usize, sx)) * 4;
            const sr = p.src[si];
            const sg = p.src[si + 1];
            const sb = p.src[si + 2];
            const sa = p.src[si + 3];
            const idx = @as(usize, @intCast(y)) * @as(usize, p.words_per_row) + @as(usize, @intCast(x));
            blendRgbaOntoUnsafe(p.pixels, idx, sr, sg, sb, sa);
        }
    }
}

noinline fn blitRgbaStretchUnsafe(p: *const BlitRgbaStretchArgs) void {
    @setRuntimeSafety(false);
    if (p.dw == 0 or p.dh == 0 or p.sw == 0 or p.sh == 0) return;
    const need = @as(usize, p.sw) * @as(usize, p.sh) * 4;
    if (p.src_len < need) return;
    const sh_m1 = p.sh - 1;
    const sw_m1 = p.sw - 1;
    var j: u32 = 0;
    while (j < p.dh) : (j += 1) {
        const sy = @min(sh_m1, (j * p.sh) / p.dh);
        var i: u32 = 0;
        while (i < p.dw) : (i += 1) {
            const sx = @min(sw_m1, (i * p.sw) / p.dw);
            const x = p.dx + i;
            const y = p.dy + j;
            if (x >= p.fb_w or y >= p.fb_h) continue;
            const si = (@as(usize, sy) * @as(usize, p.sw) + @as(usize, sx)) * 4;
            const sr = p.src[si];
            const sg = p.src[si + 1];
            const sb = p.src[si + 2];
            const sa = p.src[si + 3];
            const idx = @as(usize, @intCast(y)) * @as(usize, p.words_per_row) + @as(usize, @intCast(x));
            blendRgbaOntoUnsafe(p.pixels, idx, sr, sg, sb, sa);
        }
    }
}

pub const Canvas = struct {
    pixels: [*]volatile u32,
    info: *const mboot2.FbInfo,

    pub fn init(base: [*]align(4096) volatile u8, info: *const mboot2.FbInfo) Canvas {
        return .{
            .pixels = @ptrCast(@alignCast(base)),
            .info = info,
        };
    }

    pub fn putPixel(self: *const Canvas, x: u32, y: u32, colorref: u32) void {
        if (x >= self.info.width or y >= self.info.height) return;
        const i = @as(usize, @intCast(y)) *% @as(usize, @intCast(self.info.pitch / 4)) +% @as(usize, @intCast(x));
        self.pixels[i] = colorRefToBgra(colorref);
    }

    pub fn fillRect(self: *const Canvas, x: u32, y: u32, w: u32, h: u32, colorref: u32) void {
        const c = colorRefToBgra(colorref);
        var j: u32 = 0;
        while (j < h) : (j += 1) {
            const yy = y + j;
            if (yy >= self.info.height) break;
            var i: u32 = 0;
            while (i < w) : (i += 1) {
                const xx = x + i;
                if (xx >= self.info.width) break;
                const idx = @as(usize, @intCast(yy)) *% @as(usize, @intCast(self.info.pitch / 4)) +% @as(usize, @intCast(xx));
                self.pixels[idx] = c;
            }
        }
    }

    /// 垂直渐变（两段纯色条）。
    pub fn fillRectGradient2(self: *const Canvas, x: u32, y: u32, w: u32, h: u32, top: u32, bot: u32) void {
        if (h <= 1) {
            self.fillRect(x, y, w, h, top);
            return;
        }
        const h1 = h / 2;
        self.fillRect(x, y, w, h1, top);
        self.fillRect(x, y + h1, w, h - h1, bot);
    }

    /// 水平两段渐变（左半 `left`、右半 `right`）。
    pub fn fillRectGradient2H(self: *const Canvas, x: u32, y: u32, w: u32, h: u32, left: u32, right: u32) void {
        if (w <= 1) {
            self.fillRect(x, y, w, h, left);
            return;
        }
        const w1 = w / 2;
        self.fillRect(x, y, w1, h, left);
        self.fillRect(x + w1, y, w - w1, h, right);
    }

    /// Blit top-down RGBA8（`src_len` ≥ w×h×4）。
    pub fn blitRgba(self: *const Canvas, dx: u32, dy: u32, src: [*]const u8, src_len: usize, w: u32, h: u32) void {
        const wpr = self.info.pitch / 4;
        const args = BlitRgbaArgs{
            .pixels = self.pixels,
            .fb_w = self.info.width,
            .fb_h = self.info.height,
            .words_per_row = wpr,
            .dx = dx,
            .dy = dy,
            .src = src,
            .src_len = src_len,
            .w = w,
            .h = h,
        };
        blitRgbaUnsafe(&args);
    }

    /// 最近邻缩放 RGBA 源图到 `dw`×`dh`（`src_len` ≥ sw×sh×4）。
    pub fn blitRgbaStretch(self: *const Canvas, dx: u32, dy: u32, dw: u32, dh: u32, src: [*]const u8, src_len: usize, sw: u32, sh: u32) void {
        const wpr = self.info.pitch / 4;
        const args = BlitRgbaStretchArgs{
            .pixels = self.pixels,
            .fb_w = self.info.width,
            .fb_h = self.info.height,
            .words_per_row = wpr,
            .dx = dx,
            .dy = dy,
            .dw = dw,
            .dh = dh,
            .src = src,
            .src_len = src_len,
            .sw = sw,
            .sh = sh,
        };
        blitRgbaStretchUnsafe(&args);
    }
};

/// 将一整帧从后景 `src` 拷到显存 `dst`（`pitch` / `width`×`height` 与 `info` 一致）。
pub fn blitFullScreen(dst: [*]volatile u32, src: [*]const volatile u32, info: *const mboot2.FbInfo) void {
    @setRuntimeSafety(false);
    const w = info.width;
    const h = info.height;
    const pitch_b = info.pitch;
    const row_words = pitch_b / 4;
    if (pitch_b == w * 4) {
        const total: usize = @as(usize, w) * @as(usize, h);
        var i: usize = 0;
        while (i < total) : (i += 1) {
            dst[i] = src[i];
        }
    } else {
        var y: u32 = 0;
        while (y < h) : (y += 1) {
            const row = @as(usize, y) * @as(usize, row_words);
            var x: u32 = 0;
            while (x < w) : (x += 1) {
                dst[row + x] = src[row + x];
            }
        }
    }
}
