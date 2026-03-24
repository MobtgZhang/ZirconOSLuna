//! Software compositor: wallpaper, desktop icons, taskbar, start menu, context menu, cursor.
//! Layer order matches [render.RenderLayer](render.zig): desktop → taskbar → overlays → cursor.

const surface_mod = @import("surface.zig");
const theme = @import("theme.zig");
const shell = @import("shell.zig");
const desktop = @import("desktop.zig");
const taskbar = @import("taskbar.zig");
const startmenu = @import("startmenu.zig");
const resources = @import("resources.zig");
const resource_cache = @import("resource_cache.zig");
const shell_model = @import("shell_model.zig");

pub const layer_order = [_][]const u8{
    "desktop",
    "taskbar",
    "shell_window",
    "overlay",
    "cursor",
};

fn paintWallpaper(s: *surface_mod.RgbaSurface, tr: []const u8, width: u32, desk_h: i32) void {
    if (desk_h <= 0) return;
    const wp = desktop.getWallpaper();
    if (wp.style == .solid_color or !wp.is_set) {
        s.fillRectColorRef(0, 0, @intCast(width), desk_h, desktop.getDesktopColor(), 255);
        return;
    }
    if (tr.len == 0) {
        s.fillRectColorRef(0, 0, @intCast(width), desk_h, theme.getColors().desktop_background, 255);
        return;
    }
    const rel = wp.getPath();
    if (resource_cache.getOrLoad(tr, rel)) |bmp| {
        s.blitStretch(0, 0, @intCast(width), desk_h, bmp.rgba, bmp.width, bmp.height);
    } else {
        s.fillRectColorRef(0, 0, @intCast(width), desk_h, theme.getColors().desktop_background, 255);
    }
}

fn paintDesktopIcons(s: *surface_mod.RgbaSurface, tr: []const u8) void {
    if (tr.len == 0) return;
    var i: usize = 0;
    while (i < desktop.getIconCount()) : (i += 1) {
        const ic = desktop.getIcon(i) orelse continue;
        const rel = desktop.defaultIconResourcePath(ic.icon_type);
        const sz = theme.DESKTOP_ICON_SIZE;
        if (resource_cache.getOrLoad(tr, rel)) |bmp| {
            s.blitStretch(ic.pixel_x, ic.pixel_y, sz, sz, bmp.rgba, bmp.width, bmp.height);
        }
        if (ic.is_selected) {
            const px = ic.pixel_x;
            const py = ic.pixel_y;
            s.fillRect(px - 2, py - 2, sz + 4, 2, 255, 255, 255, 220);
            s.fillRect(px - 2, py + sz, sz + 4, 2, 255, 255, 255, 220);
            s.fillRect(px - 2, py - 2, 2, sz + 4, 255, 255, 255, 220);
            s.fillRect(px + sz, py - 2, 2, sz + 4, 255, 255, 255, 220);
        }
    }
}

fn quickLaunchPng(tr: []const u8, ordinal: usize) ?resource_cache.BitmapView {
    const rel = shell_model.quickLaunchPngRel(ordinal) orelse return null;
    return resource_cache.getOrLoad(tr, rel);
}

fn trayPng(tr: []const u8, icon_id: u32) ?resource_cache.BitmapView {
    const rel: []const u8 = switch (icon_id) {
        10 => "resources/icons/tray/icon_tray_volume.png",
        11 => "resources/icons/tray/icon_tray_network.png",
        else => resources.icons.user_default,
    };
    return resource_cache.getOrLoad(tr, rel);
}

fn startmenuIconRel(icon_id: u32) ?[]const u8 {
    return switch (icon_id) {
        20 => "resources/icons/startmenu/icon_internet.png",
        21 => "resources/icons/startmenu/icon_email.png",
        30, 31, 32, 33, 34 => "resources/icons/system/icon_mydocuments.png",
        50 => resources.icons.my_documents,
        52, 53 => resources.icons.my_documents,
        54 => resources.icons.my_computer,
        60 => resources.icons.control_panel,
        61 => resources.icons.printer,
        62 => resources.icons.help,
        63 => resources.icons.search,
        64 => resources.icons.run,
        else => null,
    };
}

fn paintTaskbar(s: *surface_mod.RgbaSurface, tr: []const u8, width: u32, height: u32, tb_h: i32) void {
    const y = @as(i32, @intCast(height)) - tb_h;
    const tc = taskbar.getTaskbarColors();
    s.fillRectGradientV(0, y, @intCast(width), tb_h, tc.bg_top, tc.bg_bottom);

    if (tr.len == 0) return;

    const sb = taskbar.getStartButton();
    if (resource_cache.getOrLoad(tr, resources.ui.start_button)) |bmp| {
        s.blitStretch(sb.x, sb.y, sb.width, sb.height, bmp.rgba, bmp.width, bmp.height);
    }

    var q: usize = 0;
    while (q < 8) : (q += 1) {
        const qx = taskbar.getQuickLaunchCellX(q) orelse break;
        const qy = y + 7;
        if (quickLaunchPng(tr, q)) |bmp| {
            s.blitStretch(qx, qy, 16, 16, bmp.rgba, bmp.width, bmp.height);
        } else {
            s.fillRect(qx, qy, 16, 16, 200, 180, 50, 255);
        }
    }

    const tw = taskbar.computeTrayWidth();
    const cw: i32 = if (taskbar.getSettings().show_clock) theme.TASKBAR_CLOCK_WIDTH else 0;
    const x0 = @as(i32, @intCast(width)) - tw - cw - 4;

    var tray_ids: [16]u32 = undefined;
    const tn = taskbar.trayPaintEnumerate(&tray_ids);
    var j: usize = 0;
    while (j < tn) : (j += 1) {
        const cell_x = x0 + 4 + @as(i32, @intCast(j * 20));
        if (trayPng(tr, tray_ids[j])) |bmp| {
            s.blitStretch(cell_x, y + 7, 16, 16, bmp.rgba, bmp.width, bmp.height);
        }
    }

    s.fillRectColorRef(x0 + tw - 4, y + 4, cw + 4, tb_h - 8, tc.tray_bg, 255);

    var clk_buf: [16]u8 = undefined;
    const clk = taskbar.getClock();
    if (clk.getTimeString(&clk_buf) > 0) {
        const cx = x0 + tw;
        s.fillRectColorRef(cx, y + 6, cw, tb_h - 12, tc.tray_bg, 255);
    }
}

fn paintMenuColumn(
    s: *surface_mod.RgbaSurface,
    tr: []const u8,
    items: []const startmenu.MenuItem,
    x0: i32,
    x1: i32,
    mut_y: *i32,
    hl_col: startmenu.MenuColumn,
    mc: anytype,
) void {
    for (items, 0..) |it, idx| {
        if (!it.is_visible) continue;
        if (it.item_type == .separator) {
            mut_y.* += theme.STARTMENU_SEPARATOR_HEIGHT;
            continue;
        }
        const h: i32 = theme.STARTMENU_ITEM_HEIGHT;
        const hi = startmenu.getHighlight();
        const is_hl = hi.column == hl_col and hi.index == @as(i32, @intCast(idx));
        const fill = if (is_hl) mc.highlight else if (hl_col == .right) mc.right_bg else mc.left_bg;
        s.fillRectColorRef(x0, mut_y.*, x1 - x0, h, fill, 255);
        if (tr.len > 0) {
            if (startmenuIconRel(it.icon_id)) |rel| {
                if (resource_cache.getOrLoad(tr, rel)) |bmp| {
                    s.blitStretch(x0 + 4, mut_y.* + 3, theme.STARTMENU_ICON_SIZE, theme.STARTMENU_ICON_SIZE, bmp.rgba, bmp.width, bmp.height);
                }
            }
        }
        if (it.item_type != .separator) {
            const tx = x0 + 4 + theme.STARTMENU_ICON_SIZE + 8;
            const ty = mut_y.* + 9;
            const tcol = if (is_hl) mc.highlight_text else mc.text;
            s.drawText8(tx, ty, it.getName(), tcol);
        }
        mut_y.* += h;
    }
}

fn paintStartMenu(s: *surface_mod.RgbaSurface, tr: []const u8) void {
    const r = startmenu.getMenuRect();
    const mc = startmenu.getMenuColors();

    s.fillRectGradientV(r.x, r.y, r.w, theme.STARTMENU_HEADER_HEIGHT, mc.header_left, mc.header_right);

    if (tr.len > 0) {
        if (resource_cache.getOrLoad(tr, resources.icons.user_default)) |bmp| {
            s.blitStretch(r.x + 10, r.y + 8, 40, 40, bmp.rgba, bmp.width, bmp.height);
        }
    }
    s.drawText8(r.x + 56, r.y + 20, startmenu.getUserDisplayName(), mc.header_text);

    const body_h = r.h - theme.STARTMENU_HEADER_HEIGHT - theme.STARTMENU_FOOTER_HEIGHT;
    s.fillRectColorRef(r.x, r.y + theme.STARTMENU_HEADER_HEIGHT, theme.STARTMENU_LEFT_WIDTH, body_h, mc.left_bg, 255);
    s.fillRectColorRef(r.x + theme.STARTMENU_LEFT_WIDTH, r.y + theme.STARTMENU_HEADER_HEIGHT, theme.STARTMENU_RIGHT_WIDTH, body_h, mc.right_bg, 255);

    var y: i32 = r.y + theme.STARTMENU_HEADER_HEIGHT;
    paintMenuColumn(s, tr, startmenu.getLeftPinnedItems(), r.x, r.x + theme.STARTMENU_LEFT_WIDTH, &y, .left_pinned, mc);
    paintMenuColumn(s, tr, startmenu.getLeftMfuItems(), r.x, r.x + theme.STARTMENU_LEFT_WIDTH, &y, .left_mfu, mc);

    y = r.y + theme.STARTMENU_HEADER_HEIGHT;
    paintMenuColumn(s, tr, startmenu.getRightItems(), r.x + theme.STARTMENU_LEFT_WIDTH, r.x + r.w, &y, .right, mc);

    const fr = startmenu.getFooterRect();
    s.fillRectColorRef(fr.x, fr.y, fr.w, fr.h, mc.footer_bg, 255);
    const mid = fr.x + @divTrunc(fr.w, 2);
    s.fillRectColorRef(mid, fr.y + 4, 1, fr.h - 8, mc.separator, 200);
    s.drawText8(fr.x + 16, fr.y + 12, "Log Off", mc.text);
    s.drawText8(mid + 12, fr.y + 12, "Turn Off Computer", mc.text);
}

fn paintContextMenu(s: *surface_mod.RgbaSurface, _: []const u8) void {
    const cm = desktop.getContextMenu();
    if (!cm.is_visible) return;
    const w: i32 = 180;
    var total_h: i32 = 0;
    for (cm.items[0..cm.item_count]) |it| {
        if (it.item_type == .separator) total_h += 4 else total_h += theme.MENU_ITEM_HEIGHT;
    }
    const colors = theme.getColors();
    s.fillRectColorRef(cm.x, cm.y, w, total_h + 4, colors.menu_background, 250);
    var y: i32 = cm.y + 2;
    for (cm.items[0..cm.item_count]) |it| {
        if (it.item_type == .separator) {
            y += 4;
            continue;
        }
        const h: i32 = theme.MENU_ITEM_HEIGHT;
        if (it.item_type != .disabled) {
            s.fillRectColorRef(cm.x + 2, y, w - 4, h, colors.menu_background, 255);
        }
        y += h;
    }
}

fn paintShellWindows(s: *surface_mod.RgbaSurface, _: []const u8) void {
    shell.paintShellWindowsToSurface(s);
}

fn paintSessionOverlay(s: *surface_mod.RgbaSurface) void {
    const st = shell.getShellState();
    if (st != .shutting_down and st != .logging_off) return;
    const w = s.width;
    const h = s.height;
    s.fillRect(0, 0, @intCast(w), @intCast(h), 20, 20, 40, 230);
    const msg = if (st == .shutting_down) "Shutting down..." else "Logging off...";
    s.drawText8(@divTrunc(@as(i32, @intCast(w)), 2) - 80, @divTrunc(@as(i32, @intCast(h)), 2), msg, theme.RGB(255, 255, 255));
}

fn paintCursorOverlay(s: *surface_mod.RgbaSurface, tr: []const u8) void {
    if (tr.len == 0) return;
    const m = shell.getMousePosition();
    const rel = if (shell.isCursorBusy()) resources.cursors.wait else resources.cursors.arrow;
    if (resource_cache.getOrLoad(tr, rel)) |c| {
        const hs = resource_cache.cursorHotspot(if (shell.isCursorBusy()) .wait else .arrow);
        const mx = m.x;
        const my = m.y;
        s.blitCopy(mx - @as(i32, @intCast(hs.x)), my - @as(i32, @intCast(hs.y)), c.rgba, c.width, c.height, 0, 0, c.width, c.height);
    }
}

/// Full-frame RGBA8888 top-down compositing into `pixels` (len ≥ width*height*4).
pub fn composeFrame(pixels: []u8, width: u32, height: u32) void {
    if (width == 0 or height == 0) return;
    const need = @as(usize, width) * @as(usize, height) * 4;
    if (pixels.len < need) return;

    var surf = surface_mod.RgbaSurface.init(pixels[0..need], width, height);

    if (shell.getShellState() == .not_started) {
        surf.fillRect(0, 0, @intCast(width), @intCast(height), 0, 0, 0, 255);
        return;
    }

    if (shell.getShellState() == .login_screen or shell.getShellState() == .locked) {
        const c = theme.getColors();
        surf.fillRectGradientV(0, 0, @intCast(width), @intCast(height), c.login_bg_top, c.login_bg_bottom);
        return;
    }

    const tr = shell.getThemeRoot();
    const tb_h = taskbar.getSettings().height;
    const desk_h = @as(i32, @intCast(height)) - tb_h;

    paintWallpaper(&surf, tr, width, desk_h);
    paintDesktopIcons(&surf, tr);
    paintShellWindows(&surf, tr);
    paintTaskbar(&surf, tr, width, height, tb_h);
    if (startmenu.isOpen()) paintStartMenu(&surf, tr);
    paintContextMenu(&surf, tr);
    paintSessionOverlay(&surf);
    paintCursorOverlay(&surf, tr);
}

/// 命中测试定义在 [shell.zig](shell.zig)（避免 shell↔compositor 循环依赖）。
pub const HitPick = shell.DesktopHitPick;

pub fn hitTestAt(mx: i32, my: i32) HitPick {
    return shell.desktopHitPick(mx, my);
}
