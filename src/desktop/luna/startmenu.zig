//! Start Menu - ZirconOS Luna XP-Style Start Menu
//! Implements the two-column Windows XP Start Menu with user header,
//! pinned programs, MFU list, and system locations.
//! Reference: ReactOS explorer (base/shell/explorer/startmenu.cpp)

const theme = @import("theme.zig");
const menu_data = @import("startmenu_data.zig");

pub const COLORREF = theme.COLORREF;

// ── Menu Item ──

pub const MAX_MENU_ITEMS: usize = 32;
pub const MAX_ITEM_NAME_LEN: usize = 48;
pub const MAX_ITEM_PATH_LEN: usize = 128;

pub const MenuColumn = enum(u8) {
    left_pinned = 0,
    left_mfu = 1,
    right = 2,
};

pub const MenuItemType = enum(u8) {
    program = 0,
    folder = 1,
    separator = 2,
    system_link = 3,
    action = 4,
};

pub const MenuItem = struct {
    name: [MAX_ITEM_NAME_LEN]u8 = [_]u8{0} ** MAX_ITEM_NAME_LEN,
    name_len: usize = 0,
    description: [64]u8 = [_]u8{0} ** 64,
    description_len: usize = 0,
    target_path: [MAX_ITEM_PATH_LEN]u8 = [_]u8{0} ** MAX_ITEM_PATH_LEN,
    target_path_len: usize = 0,
    icon_id: u32 = 0,
    column: MenuColumn = .left_pinned,
    item_type: MenuItemType = .program,
    is_bold: bool = false,
    has_arrow: bool = false,
    is_highlighted: bool = false,
    is_visible: bool = true,
    y_offset: i32 = 0,

    pub fn getName(self: *const MenuItem) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn getDescription(self: *const MenuItem) []const u8 {
        return self.description[0..self.description_len];
    }
};

// ── Start Menu Sections ──

pub const StartMenuState = enum(u8) {
    closed = 0,
    opening = 1,
    open = 2,
    closing = 3,
    submenu_open = 4,
};

pub const FooterButton = enum(u8) {
    log_off = 0,
    shut_down = 1,
};

// ── Global State ──

var left_pinned_items: [MAX_MENU_ITEMS]MenuItem = [_]MenuItem{.{}} ** MAX_MENU_ITEMS;
var left_pinned_count: usize = 0;

var left_mfu_items: [MAX_MENU_ITEMS]MenuItem = [_]MenuItem{.{}} ** MAX_MENU_ITEMS;
var left_mfu_count: usize = 0;

var right_items: [MAX_MENU_ITEMS]MenuItem = [_]MenuItem{.{}} ** MAX_MENU_ITEMS;
var right_count: usize = 0;

var menu_state: StartMenuState = .closed;
var highlight_column: MenuColumn = .left_pinned;
var highlight_index: i32 = -1;
var footer_highlight: i32 = -1;

var user_display_name: [64]u8 = [_]u8{0} ** 64;
var user_display_name_len: usize = 0;
var user_avatar_id: u32 = 0;

var menu_x: i32 = 0;
var menu_y: i32 = 0;
var startmenu_initialized: bool = false;

const NavSlot = struct { col: MenuColumn, idx: usize };
var nav_slots: [64]NavSlot = undefined;
var nav_count: usize = 0;
var menu_nav_index: usize = 0;

// ── Menu Construction ──

fn addItem(
    list: []MenuItem,
    count: *usize,
    name: []const u8,
    desc: []const u8,
    path: []const u8,
    icon_id: u32,
    column: MenuColumn,
    item_type: MenuItemType,
    bold: bool,
    arrow: bool,
) void {
    if (count.* >= list.len) return;
    var item = &list[count.*];
    item.* = .{};
    item.icon_id = icon_id;
    item.column = column;
    item.item_type = item_type;
    item.is_bold = bold;
    item.has_arrow = arrow;
    item.is_visible = true;

    const nn = @min(name.len, MAX_ITEM_NAME_LEN);
    @memcpy(item.name[0..nn], name[0..nn]);
    item.name_len = nn;

    const dd = @min(desc.len, item.description.len);
    @memcpy(item.description[0..dd], desc[0..dd]);
    item.description_len = dd;

    const pp = @min(path.len, MAX_ITEM_PATH_LEN);
    @memcpy(item.target_path[0..pp], path[0..pp]);
    item.target_path_len = pp;

    count.* += 1;
}

fn mapDataColumn(c: menu_data.Col) MenuColumn {
    return switch (c) {
        .left_pinned => .left_pinned,
        .left_mfu => .left_mfu,
        .right => .right,
    };
}

fn mapDataKind(k: menu_data.Kind) MenuItemType {
    return switch (k) {
        .program => .program,
        .folder => .folder,
        .separator => .separator,
        .system_link => .system_link,
    };
}

fn buildDefaultMenu() void {
    left_pinned_count = 0;
    left_mfu_count = 0;
    right_count = 0;

    for (menu_data.left_pinned) |row| {
        addItem(
            &left_pinned_items, &left_pinned_count,
            row.name, row.desc, row.path, row.icon_id,
            mapDataColumn(row.column), mapDataKind(row.item_type), row.bold, row.arrow,
        );
    }
    for (menu_data.left_mfu) |row| {
        addItem(
            &left_mfu_items, &left_mfu_count,
            row.name, row.desc, row.path, row.icon_id,
            mapDataColumn(row.column), mapDataKind(row.item_type), row.bold, row.arrow,
        );
    }
    for (menu_data.right) |row| {
        addItem(
            &right_items, &right_count,
            row.name, row.desc, row.path, row.icon_id,
            mapDataColumn(row.column), mapDataKind(row.item_type), row.bold, row.arrow,
        );
    }
}

// ── Menu State ──

pub fn openMenu(x: i32, y: i32) void {
    menu_x = x;
    menu_y = y - theme.STARTMENU_HEIGHT;
    menu_state = .open;
    highlight_index = -1;
    footer_highlight = -1;
    rebuildNavSlots();
    menu_nav_index = 0;
    applyNavIndex();
}

fn rebuildNavSlots() void {
    nav_count = 0;
    appendNavColumn(.left_pinned, left_pinned_items[0..left_pinned_count]);
    appendNavColumn(.left_mfu, left_mfu_items[0..left_mfu_count]);
    appendNavColumn(.right, right_items[0..right_count]);
}

fn appendNavColumn(col: MenuColumn, list: []const MenuItem) void {
    for (list, 0..) |it, i| {
        if (!it.is_visible) continue;
        if (it.item_type == .separator) continue;
        if (it.item_type == .folder) continue;
        if (nav_count >= nav_slots.len) return;
        nav_slots[nav_count] = .{ .col = col, .idx = i };
        nav_count += 1;
    }
}

fn applyNavIndex() void {
    if (nav_count == 0) return;
    if (menu_nav_index >= nav_count) menu_nav_index = nav_count - 1;
    const s = nav_slots[menu_nav_index];
    highlight_column = s.col;
    highlight_index = @intCast(s.idx);
}

fn syncNavFromHighlight() void {
    for (nav_slots[0..nav_count], 0..) |s, i| {
        if (s.col == highlight_column and s.idx == @as(usize, @intCast(highlight_index))) {
            menu_nav_index = i;
            return;
        }
    }
}

pub fn moveMenuHighlight(delta: i32) void {
    if (nav_count == 0) return;
    var ni = @as(isize, @intCast(menu_nav_index)) + @as(isize, @intCast(delta));
    const nc: isize = @intCast(nav_count);
    while (ni < 0) ni += nc;
    while (ni >= nc) ni -= nc;
    menu_nav_index = @intCast(ni);
    applyNavIndex();
}

fn itemPathForSlot(s: NavSlot) ?[]const u8 {
    switch (s.col) {
        .left_pinned => {
            if (s.idx >= left_pinned_count) return null;
            const it = left_pinned_items[s.idx];
            if (it.target_path_len == 0) return null;
            return it.target_path[0..it.target_path_len];
        },
        .left_mfu => {
            if (s.idx >= left_mfu_count) return null;
            const it = left_mfu_items[s.idx];
            if (it.target_path_len == 0) return null;
            return it.target_path[0..it.target_path_len];
        },
        .right => {
            if (s.idx >= right_count) return null;
            const it = right_items[s.idx];
            if (it.target_path_len == 0) return null;
            return it.target_path[0..it.target_path_len];
        },
    }
}

pub fn activateHighlighted() ?[]const u8 {
    if (!isOpen() or nav_count == 0) return null;
    return itemPathForSlot(nav_slots[menu_nav_index]);
}

pub fn hitTestFooter(mx: i32, my: i32) ?FooterButton {
    const fr = getFooterRect();
    if (mx < fr.x or my < fr.y or mx >= fr.x + fr.w or my >= fr.y + fr.h) return null;
    const half = @divTrunc(fr.w, 2);
    if (mx < fr.x + half) return .log_off;
    return .shut_down;
}

fn scanColumnHit(mx: i32, my: i32, col: MenuColumn, list: []const MenuItem, x0: i32, x1: i32, mut_y: *i32) ?[]const u8 {
    for (list, 0..) |it, i| {
        if (!it.is_visible) continue;
        if (it.item_type == .separator) {
            mut_y.* += theme.STARTMENU_SEPARATOR_HEIGHT;
            continue;
        }
        const h: i32 = theme.STARTMENU_ITEM_HEIGHT;
        if (mx >= x0 and mx < x1 and my >= mut_y.* and my < mut_y.* + h) {
            highlight_column = col;
            highlight_index = @intCast(i);
            syncNavFromHighlight();
            if (it.target_path_len > 0) return it.target_path[0..it.target_path_len];
            return null;
        }
        mut_y.* += h;
    }
    return null;
}

pub fn hitTestItem(mx: i32, my: i32) bool {
    if (!isOpen()) return false;
    const r = getMenuRect();
    if (mx < r.x or mx >= r.x + r.w or my < r.y or my >= r.y + r.h) return false;

    var y: i32 = menu_y + theme.STARTMENU_HEADER_HEIGHT;
    _ = scanColumnHit(mx, my, .left_pinned, left_pinned_items[0..left_pinned_count], menu_x, menu_x + theme.STARTMENU_LEFT_WIDTH, &y);
    _ = scanColumnHit(mx, my, .left_mfu, left_mfu_items[0..left_mfu_count], menu_x, menu_x + theme.STARTMENU_LEFT_WIDTH, &y);

    y = menu_y + theme.STARTMENU_HEADER_HEIGHT;
    const rx0 = menu_x + theme.STARTMENU_LEFT_WIDTH;
    const rx1 = menu_x + theme.STARTMENU_WIDTH;
    _ = scanColumnHit(mx, my, .right, right_items[0..right_count], rx0, rx1, &y);
    return true;
}

pub fn activateHitItem(mx: i32, my: i32) ?[]const u8 {
    if (!isOpen()) return null;
    const r = getMenuRect();
    if (mx < r.x or mx >= r.x + r.w or my < r.y or my >= r.y + r.h) return null;

    var y: i32 = menu_y + theme.STARTMENU_HEADER_HEIGHT;
    if (scanColumnHit(mx, my, .left_pinned, left_pinned_items[0..left_pinned_count], menu_x, menu_x + theme.STARTMENU_LEFT_WIDTH, &y)) |p| return p;
    if (scanColumnHit(mx, my, .left_mfu, left_mfu_items[0..left_mfu_count], menu_x, menu_x + theme.STARTMENU_LEFT_WIDTH, &y)) |p| return p;

    y = menu_y + theme.STARTMENU_HEADER_HEIGHT;
    const rx0 = menu_x + theme.STARTMENU_LEFT_WIDTH;
    const rx1 = menu_x + theme.STARTMENU_WIDTH;
    if (scanColumnHit(mx, my, .right, right_items[0..right_count], rx0, rx1, &y)) |p| return p;

    return null;
}

pub fn closeMenu() void {
    menu_state = .closed;
    highlight_index = -1;
    footer_highlight = -1;
}

pub fn isOpen() bool {
    return menu_state == .open or menu_state == .submenu_open;
}

pub fn getState() StartMenuState {
    return menu_state;
}

// ── Menu Geometry ──

pub fn getMenuRect() struct { x: i32, y: i32, w: i32, h: i32 } {
    return .{
        .x = menu_x,
        .y = menu_y,
        .w = theme.STARTMENU_WIDTH,
        .h = theme.STARTMENU_HEIGHT,
    };
}

pub fn getHeaderRect() struct { x: i32, y: i32, w: i32, h: i32 } {
    return .{
        .x = menu_x,
        .y = menu_y,
        .w = theme.STARTMENU_WIDTH,
        .h = theme.STARTMENU_HEADER_HEIGHT,
    };
}

pub fn getFooterRect() struct { x: i32, y: i32, w: i32, h: i32 } {
    return .{
        .x = menu_x,
        .y = menu_y + theme.STARTMENU_HEIGHT - theme.STARTMENU_FOOTER_HEIGHT,
        .w = theme.STARTMENU_WIDTH,
        .h = theme.STARTMENU_FOOTER_HEIGHT,
    };
}

// ── Data Access ──

pub fn getLeftPinnedItems() []const MenuItem {
    return left_pinned_items[0..left_pinned_count];
}

pub fn getLeftMfuItems() []const MenuItem {
    return left_mfu_items[0..left_mfu_count];
}

pub fn getRightItems() []const MenuItem {
    return right_items[0..right_count];
}

pub fn getHighlight() struct { column: MenuColumn, index: i32 } {
    return .{ .column = highlight_column, .index = highlight_index };
}

pub fn setHighlight(column: MenuColumn, index: i32) void {
    highlight_column = column;
    highlight_index = index;
}

pub fn setFooterHighlight(index: i32) void {
    footer_highlight = index;
}

pub fn getFooterHighlight() i32 {
    return footer_highlight;
}

// ── User Info ──

pub fn setUserInfo(name: []const u8, avatar_id: u32) void {
    const n = @min(name.len, user_display_name.len);
    @memcpy(user_display_name[0..n], name[0..n]);
    user_display_name_len = n;
    user_avatar_id = avatar_id;
}

pub fn getUserDisplayName() []const u8 {
    return user_display_name[0..user_display_name_len];
}

pub fn getUserAvatarId() u32 {
    return user_avatar_id;
}

// ── Menu Colors ──

pub fn getMenuColors() struct {
    header_left: COLORREF,
    header_right: COLORREF,
    header_text: COLORREF,
    left_bg: COLORREF,
    right_bg: COLORREF,
    highlight: COLORREF,
    highlight_text: COLORREF,
    text: COLORREF,
    footer_bg: COLORREF,
    separator: COLORREF,
} {
    const colors = theme.getColors();
    return .{
        .header_left = theme.RGB(0xE8, 0x78, 0x28),
        .header_right = theme.RGB(0xF5, 0xB0, 0x48),
        .header_text = theme.RGB(0xFF, 0xFF, 0xFF),
        .left_bg = theme.RGB(0xFF, 0xFF, 0xFF),
        .right_bg = theme.RGB(0xD3, 0xE5, 0xFA),
        .highlight = theme.RGB(0x31, 0x6A, 0xC5),
        .highlight_text = theme.RGB(0xFF, 0xFF, 0xFF),
        .text = colors.menu_text,
        .footer_bg = theme.RGB(0xD7, 0xE4, 0xF2),
        .separator = colors.menu_separator,
    };
}

// ── Initialization ──

pub fn init() void {
    menu_state = .closed;
    highlight_index = -1;
    footer_highlight = -1;

    buildDefaultMenu();

    setUserInfo("ZirconOS User", 0);
    startmenu_initialized = true;
}
