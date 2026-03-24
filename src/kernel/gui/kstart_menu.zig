//! 内核 Luna 简化「开始」菜单（双栏 + 顶栏 + 底栏），风格接近 XP Luna。

const fb = @import("../hal/fb.zig");
const font8 = @import("../font8.zig");
const icons = @import("luna_icons.zig");
const mboot2 = @import("../mm/mboot2.zig");
const serial = @import("../hal/serial.zig");

pub const TASKBAR_H: u32 = 38;
pub const START_W: u32 = 100;
pub const START_H: u32 = TASKBAR_H - 6;

const MENU_W: u32 = 300;
const MENU_H: u32 = 280;
const HEADER_H: u32 = 52;
const FOOTER_H: u32 = 36;
const LEFT_COL_W: u32 = 150;
const ROW_H: u32 = 30;
const ICON_DST: u32 = 22;

const hdr_orange_a: u32 = 0x003698E1;
const hdr_orange_b: u32 = 0x0049B0F0;
const left_bg: u32 = 0x00FFFFFF;
const right_bg: u32 = 0x00F2E5D3;
const footer_bg: u32 = 0x00F2E4D7;
const border_col: u32 = 0x00606060;
const text_dark: u32 = 0x00000000;
const text_hdr: u32 = 0x00FFFFFF;

const menu_labels = [_][]const u8{
    "INTERNET",
    "E MAIL",
    "MY DOCUMENTS",
    "MY COMPUTER",
    "CONTROL PANEL",
};

const item_rgba = [_][]const u8{
    icons.internet,
    icons.internet,
    icons.my_documents,
    icons.my_computer,
    icons.network,
};

const menu_item_count: u32 = menu_labels.len;

pub const FooterAction = enum { log_off, turn_off };

fn drawText(c: *const fb.Canvas, x: u32, y: u32, s: []const u8, colorref: u32) void {
    var cx = x;
    var si: usize = 0;
    while (si != s.len) : (si += 1) {
        const ch = s[si];
        const oc = if ((ch >= ('a')) and (ch <= ('z'))) ch - 32 else ch;
        const g = font8.glyph(oc) orelse continue;
        var row: u32 = 0;
        while (row != 8) : (row += 1) {
            var col: u32 = 0;
            while (col != 8) : (col += 1) {
                if ((g[row] >> @intCast(7 - col)) & 1 != 0) {
                    c.putPixel(cx + col, y + row, colorref);
                }
            }
        }
        cx += 9;
    }
}

pub fn menuOrigin(screen_h: u32) struct { x: u32, y: u32 } {
    const need = TASKBAR_H + MENU_H;
    const yy: u32 = if (screen_h > need) screen_h - need else 0;
    return .{ .x = 2, .y = yy };
}

pub fn startButtonRect(tb_y: u32) struct { x: u32, y: u32, w: u32, h: u32 } {
    return .{ .x = 6, .y = tb_y + 3, .w = START_W, .h = START_H };
}

pub fn hitStartButton(mx: i32, my: i32, tb_y: u32) bool {
    const r = startButtonRect(tb_y);
    if (mx < 0 or my < 0) return false;
    const ux: u32 = @intCast(mx);
    const uy: u32 = @intCast(my);
    return (ux >= (r.x)) and (ux < (r.x + r.w)) and (uy >= (r.y)) and (uy < (r.y + r.h));
}

pub fn menuContains(mx: i32, my: i32, screen_h: u32) bool {
    if (mx < 0 or my < 0) return false;
    const ux: u32 = @intCast(mx);
    const uy: u32 = @intCast(my);
    const o = menuOrigin(screen_h);
    return (ux >= (o.x)) and (uy >= (o.y)) and (ux < (o.x + MENU_W)) and (uy < (o.y + MENU_H));
}

pub fn itemIndex(mx: i32, my: i32, screen_h: u32) ?usize {
    if (mx < 0 or my < 0) return null;
    const ux: u32 = @intCast(mx);
    const uy: u32 = @intCast(my);
    const o = menuOrigin(screen_h);
    if ((ux < (o.x)) or (ux >= (o.x + LEFT_COL_W))) return null;
    const rel_y = uy - o.y;
    if ((rel_y < (HEADER_H)) or (rel_y >= (MENU_H - FOOTER_H))) return null;
    const row = (rel_y - HEADER_H) / ROW_H;
    if (row >= (menu_item_count)) return null;
    return row;
}

pub fn footerHit(mx: i32, my: i32, screen_h: u32) ?FooterAction {
    if (!menuContains(mx, my, screen_h)) return null;
    const ux: u32 = @intCast(mx);
    const uy: u32 = @intCast(my);
    const o = menuOrigin(screen_h);
    const fy = o.y + MENU_H - FOOTER_H;
    if ((uy < fy) or (uy >= (o.y + MENU_H))) return null;
    if (ux < (o.x + MENU_W / 2)) return .log_off;
    return .turn_off;
}

pub fn draw(c: *const fb.Canvas, info: *const mboot2.FbInfo, open: bool) void {
    if (!open) return;

    const o = menuOrigin(info.height);
    if ((o.y + MENU_H) > (info.height)) return;

    c.fillRect((o.x) -| 1, (o.y) -| 1, MENU_W + 2, MENU_H + 2, border_col);
    c.fillRectGradient2H(o.x, o.y, MENU_W, HEADER_H, hdr_orange_a, hdr_orange_b);
    drawText(c, o.x + 52, o.y + 18, "ZIRCON USER", text_hdr);

    const body_h = (MENU_H - HEADER_H) - FOOTER_H;
    c.fillRect(o.x, o.y + HEADER_H, LEFT_COL_W, body_h, left_bg);
    c.fillRect(o.x + LEFT_COL_W, o.y + HEADER_H, MENU_W - LEFT_COL_W, body_h, right_bg);

    c.blitRgbaStretch(o.x + 10, o.y + 10, 36, 36, icons.my_computer.ptr, icons.my_computer.len, icons.size, icons.size);

    var row: u32 = 0;
    while (row != (menu_item_count)) : (row += 1) {
        const iy = o.y + HEADER_H + row * ROW_H + 4;
        const ix = o.x + 6;
        c.blitRgbaStretch(ix, iy, ICON_DST, ICON_DST, item_rgba[row].ptr, item_rgba[row].len, icons.size, icons.size);
        drawText(c, ix + ICON_DST + 6, iy + 6, menu_labels[row], text_dark);
    }

    const fy = o.y + MENU_H - FOOTER_H;
    c.fillRect(o.x, fy, MENU_W, FOOTER_H, footer_bg);
    c.fillRect(o.x + MENU_W / 2, fy + 4, 1, FOOTER_H - 8, border_col);
    drawText(c, o.x + 12, fy + 12, "LOG OFF", text_dark);
    drawText(c, o.x + MENU_W / 2 + 12, fy + 12, "TURN OFF", text_dark);
}

pub fn logItemActivation(idx: usize) void {
    _ = idx;
    serial.writeStrLn("[Luna] start menu item");
}
