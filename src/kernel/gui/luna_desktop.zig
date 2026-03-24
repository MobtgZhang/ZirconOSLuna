//! Luna 桌面：嵌入壁纸（拉伸）+ 32×32 图标 + 双缓冲 + 箭头光标 + 简化开始菜单。

const fb = @import("../hal/fb.zig");
const font8 = @import("../font8.zig");
const kbd = @import("../hal/kbd.zig");
const ps2_mouse = @import("../hal/ps2_mouse.zig");
const mboot2 = @import("../mm/mboot2.zig");
const pmm = @import("../mm/pmm.zig");
const fb_map = @import("../mm/fb_map.zig");
const serial = @import("../hal/serial.zig");
const icons = @import("luna_icons.zig");
const cursor = @import("luna_cursor.zig");
const wallpaper = @import("luna_wallpaper.zig");
const kstart = @import("kstart_menu.zig");

const task_top: u32 = 0x00E35400;
const task_bot: u32 = 0x00D05001;
const start_top: u32 = 0x008D3C2E;
const start_bot: u32 = 0x00AA3F3B;
const start_txt: u32 = 0x00FFFFFF;
const clock_txt: u32 = 0x00FFFFFF;
const tray: u32 = 0x00EB8A0E;
const label_txt: u32 = 0x00FFFFFF;
const sel_outline: u32 = 0x00FFFFFF;

const MOUSE_SENS_NUM: i32 = 2;
const MOUSE_SENS_DEN: i32 = 1;
const FRAME_SPIN_ITERATIONS: u32 = 2048;

/// 避免 `run` 栈上大 `Canvas` + sret 临时区与 Debug memcpy 破坏返回地址（见 #PF err=I/D, rip≈0xff……）。
var g_canvas: fb.Canvas = undefined;
/// `run` 开始时赋值；`noinline lunaRenderFrame` 读取，避免 `run` 栈帧与绘制路径叠加过大。
var g_fb_info: *const mboot2.FbInfo = undefined;
var g_front_u32: [*]volatile u32 = undefined;

const LunaRenderParams = struct {
    workspace_h: u32,
    mx: i32,
    my: i32,
    tick: u32,
    buf: *[11]u8,
    selected: ?usize,
    menu_open: bool,
    double_buf: bool,
};

var g_render: LunaRenderParams = undefined;

/// 无参数：避免 x86-64 System V 下 >6 个标量栈参 + Debug 大帧时从错误 `[rbp+off]` 读参。
noinline fn lunaRenderFrame() void {
    @setRuntimeSafety(false);
    const info = g_fb_info;
    const rp = g_render;
    g_canvas.blitRgbaStretch(0, 0, info.width, rp.workspace_h, wallpaper.rgba.ptr, wallpaper.rgba.len, wallpaper.width, wallpaper.height);

    drawDesktopChrome(&g_canvas, rp.workspace_h, rp.selected);

    const tb_y = info.height - kstart.TASKBAR_H;
    g_canvas.fillRectGradient2(0, tb_y, info.width, kstart.TASKBAR_H, task_top, task_bot);

    const sx: u32 = 6;
    const sy = tb_y + 3;
    g_canvas.fillRectGradient2(sx, sy, kstart.START_W, kstart.START_H, start_top, start_bot);
    drawText(&g_canvas, sx + 8, sy + 12, "START", start_txt);

    g_canvas.fillRect(info.width -% 120, tb_y + 4, 110, kstart.TASKBAR_H -% 8, tray);
    const dec = u32ToDec(rp.buf, rp.tick);
    drawText(&g_canvas, info.width -% 115, tb_y + 11, dec, clock_txt);
    drawText(&g_canvas, info.width -% 115 + @as(u32, @intCast(dec.len)) * 9, tb_y + 11, " TICKS", clock_txt);

    kstart.draw(&g_canvas, info, rp.menu_open);

    drawCursor(&g_canvas, rp.mx, rp.my);

    if (rp.double_buf) {
        fb.blitFullScreen(g_front_u32, g_canvas.pixels, info);
    }
}

const DesktopEntry = struct {
    label: []const u8,
    rgba: []const u8,
};

const desktop_entries = [_]DesktopEntry{
    .{ .label = "My Computer", .rgba = icons.my_computer },
    .{ .label = "My Documents", .rgba = icons.my_documents },
    .{ .label = "My Network", .rgba = icons.network },
    .{ .label = "Recycle Bin", .rgba = icons.recycle_empty },
    .{ .label = "Internet", .rgba = icons.internet },
};

fn drawText(c: *const fb.Canvas, x: u32, y: u32, s: []const u8, colorref: u32) void {
    var cx = x;
    for (s) |ch| {
        const g = font8.glyph(ch) orelse continue;
        var row: u32 = 0;
        while (row < 8) : (row += 1) {
            var col: u32 = 0;
            while (col < 8) : (col += 1) {
                if ((g[row] >> @intCast(7 - col)) & 1 != 0) {
                    c.putPixel(cx + col, y + row, colorref);
                }
            }
        }
        cx += 9;
    }
}

fn u32ToDec(buf: *[11]u8, v: u32) []const u8 {
    if (v == 0) {
        buf[0] = '0';
        return buf[0..1];
    }
    var i: usize = 0;
    var n = v;
    while (n > 0) : (n /= 10) {
        buf[i] = @intCast('0' + (n % 10));
        i += 1;
    }
    var j: usize = 0;
    while (j < i / 2) : (j += 1) {
        const t = buf[j];
        buf[j] = buf[i - 1 - j];
        buf[i - 1 - j] = t;
    }
    return buf[0..i];
}

fn drawCursor(c: *const fb.Canvas, mx: i32, my: i32) void {
    const hx: i32 = @intCast(cursor.hotspot_x);
    const hy: i32 = @intCast(cursor.hotspot_y);
    const ox = mx - hx;
    const oy = my - hy;
    c.blitRgba(@intCast(ox), @intCast(oy), cursor.rgba.ptr, cursor.rgba.len, cursor.width, cursor.height);
}

fn maxIconRows(workspace_h: u32) u32 {
    const ICON_MARGIN: u32 = 10;
    const ICON_SPACING_Y: u32 = 75;
    if (workspace_h <= ICON_MARGIN + ICON_SPACING_Y) return 1;
    const usable = workspace_h - ICON_MARGIN;
    const n = usable / ICON_SPACING_Y;
    return if (n < 1) 1 else n;
}

fn iconPixelXY(index: usize, workspace_h: u32) struct { x: u32, y: u32 } {
    const ICON_MARGIN: u32 = 10;
    const ICON_SPACING_X: u32 = 75;
    const ICON_SPACING_Y: u32 = 75;
    const mr = maxIconRows(workspace_h);
    const gx = index / mr;
    const gy = index % mr;
    return .{
        .x = ICON_MARGIN + @as(u32, @intCast(gx)) * ICON_SPACING_X,
        .y = ICON_MARGIN + @as(u32, @intCast(gy)) * ICON_SPACING_Y,
    };
}

fn hitTestIcon(mx: i32, my: i32, workspace_h: u32) ?usize {
    const ICON_SPACING_X: u32 = 75;
    const ICON_SPACING_Y: u32 = 75;
    if (mx < 0 or my < 0) return null;
    const ux: u32 = @intCast(mx);
    const uy: u32 = @intCast(my);
    var i: usize = desktop_entries.len;
    while (i > 0) {
        i -= 1;
        const p = iconPixelXY(i, workspace_h);
        if (ux >= p.x and ux < p.x + ICON_SPACING_X and uy >= p.y and uy < p.y + ICON_SPACING_Y) {
            return i;
        }
    }
    return null;
}

fn drawDesktopChrome(
    c: *const fb.Canvas,
    workspace_h: u32,
    selected: ?usize,
) void {
    const ICON_SZ_LOCAL: u32 = icons.size;
    var i: usize = 0;
    while (i < desktop_entries.len) : (i += 1) {
        const e = desktop_entries[i];
        const p = iconPixelXY(i, workspace_h);
        c.blitRgba(p.x, p.y, e.rgba.ptr, e.rgba.len, ICON_SZ_LOCAL, ICON_SZ_LOCAL);

        if (selected) |s| {
            if (s == i) {
                const x = p.x;
                const y = p.y;
                const w = ICON_SZ_LOCAL;
                const h = ICON_SZ_LOCAL;
                c.fillRect(x -| 2, y -| 2, w + 4, 2, sel_outline);
                c.fillRect(x -| 2, y + h, w + 4, 2, sel_outline);
                c.fillRect(x -| 2, y -| 2, 2, h + 4, sel_outline);
                c.fillRect(x + w, y -| 2, 2, h + 4, sel_outline);
            }
        }

        const ly = p.y + ICON_SZ_LOCAL + 3;
        drawText(c, p.x, ly, e.label, label_txt);
    }
}

/// `info` 须指向稳定内存（如 `init.framebuffer` 载荷）；勿按值传入 `FbInfo`，否则 Debug 下 `run` 内 rep movsb 会从错误栈槽拷贝并 #PF。
pub fn run(base: [*]align(4096) volatile u8, info: *const mboot2.FbInfo) noreturn {
    @setRuntimeSafety(false);
    g_fb_info = info;
    kbd.init();
    ps2_mouse.init();

    const front_u32: [*]volatile u32 = @ptrCast(@alignCast(base));
    g_front_u32 = front_u32;
    const fb_bytes = @as(u64, info.pitch) *% @as(u64, info.height);
    var double_buf = false;
    const canvas_base: [*]align(4096) volatile u8 = blk: {
        const bp = pmm.tryAllocContiguousBytes(fb_bytes) orelse break :blk base;
        // 帧缓冲在高半部时，后景不能再用裸物理指针访问（易 #PF）；映射到 FB 之后的 VA。
        if (@intFromPtr(base) >= fb_map.FB_VIRT_BASE) {
            if (fb_map.mapFramebufferBackBuffer(info, bp, fb_bytes)) |v| {
                double_buf = true;
                break :blk v;
            }
            serial.writeStrLn("[Luna] back buffer: high-V map failed, single buffer");
            break :blk base;
        }
        double_buf = true;
        break :blk @ptrFromInt(bp);
    };
    g_canvas = fb.Canvas.init(canvas_base, info);

    if (double_buf) {
        serial.writeStrLn("[Luna] kernel desktop + double buffer (PMM back)");
    } else {
        serial.writeStrLn("[Luna] kernel desktop + single buffer (no PMM back)");
    }
    serial.writeStrLn("[Luna] wallpaper: embedded 320x180 RGBA stretch");
    serial.writeStrLn("[Luna] cursor: embedded 32x32 arrow");

    var tick: u32 = 0;
    var buf: [11]u8 = undefined;
    var mx: i32 = @intCast(info.width / 2);
    var my: i32 = @intCast(info.height / 2);
    const wlim: i32 = @intCast(info.width);
    const hlim: i32 = @intCast(info.height);
    const hx: i32 = @intCast(cursor.hotspot_x);
    const hy: i32 = @intCast(cursor.hotspot_y);
    const cw: i32 = @intCast(cursor.width);
    const ch: i32 = @intCast(cursor.height);
    const workspace_h = info.height - kstart.TASKBAR_H;

    var selected: ?usize = null;
    var prev_left: bool = false;
    var menu_open: bool = false;

    while (true) : (tick +%= 1) {
        while (ps2_mouse.poll()) |m| {
            const sdx = @divTrunc(@as(i32, m.dx) * MOUSE_SENS_NUM, MOUSE_SENS_DEN);
            const sdy = @divTrunc(@as(i32, m.dy) * MOUSE_SENS_NUM, MOUSE_SENS_DEN);
            mx += sdx;
            my -= sdy;
            const max_mx = wlim - cw + hx;
            const max_my = hlim - ch + hy;
            mx = if (mx < hx) hx else if (mx > max_mx) max_mx else mx;
            my = if (my < hy) hy else if (my > max_my) max_my else my;

            if (m.left and !prev_left) {
                const tb_y_u = info.height - kstart.TASKBAR_H;
                const tb_y: u32 = tb_y_u;
                const wsy: i32 = @intCast(workspace_h);

                if (kstart.hitStartButton(mx, my, tb_y)) {
                    menu_open = !menu_open;
                } else if (menu_open) {
                    if (kstart.menuContains(mx, my, info.height)) {
                        if (kstart.itemIndex(mx, my, info.height)) |idx| {
                            kstart.logItemActivation(idx);
                            menu_open = false;
                        } else if (kstart.footerHit(mx, my, info.height)) |fa| {
                            switch (fa) {
                                .log_off => serial.writeStrLn("[Luna] Log Off"),
                                .turn_off => serial.writeStrLn("[Luna] Turn Off Computer"),
                            }
                            menu_open = false;
                        }
                    } else {
                        menu_open = false;
                        if (my < wsy) {
                            if (hitTestIcon(mx, my, workspace_h)) |idx| {
                                selected = idx;
                                serial.writeStr("[Luna] icon ");
                                serial.writeByte(@intCast('0' + @as(u8, @intCast(idx))));
                                serial.writeStrLn("");
                            } else {
                                selected = null;
                            }
                        }
                    }
                } else if (my < wsy) {
                    if (hitTestIcon(mx, my, workspace_h)) |idx| {
                        selected = idx;
                        serial.writeStr("[Luna] icon ");
                        serial.writeByte(@intCast('0' + @as(u8, @intCast(idx))));
                        serial.writeStrLn("");
                    } else {
                        selected = null;
                    }
                }
            }
            prev_left = m.left;
        }
        while (kbd.pollKey()) |key| {
            if (key == '\r') {
                serial.writeStrLn("[Luna] Enter");
            } else {
                serial.writeStr("[Luna] key ");
                serial.writeByte(key);
                serial.writeStrLn("");
            }
        }

        g_render = .{
            .workspace_h = workspace_h,
            .mx = mx,
            .my = my,
            .tick = tick,
            .buf = &buf,
            .selected = selected,
            .menu_open = menu_open,
            .double_buf = double_buf,
        };
        lunaRenderFrame();

        var spin: u32 = 0;
        while (spin < FRAME_SPIN_ITERATIONS) : (spin += 1) {
            asm volatile ("pause" ::: .{ .memory = true });
        }
    }
}
