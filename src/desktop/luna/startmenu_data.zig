//! 开始菜单静态种子（数据驱动）；列/类型用本地枚举，避免与 `startmenu.zig` 循环依赖。

pub const Col = enum { left_pinned, left_mfu, right };
pub const Kind = enum { program, folder, separator, system_link };

pub const Row = struct {
    name: []const u8,
    desc: []const u8,
    path: []const u8,
    icon_id: u32,
    column: Col,
    item_type: Kind,
    bold: bool,
    arrow: bool,
};

pub const left_pinned: []const Row = &.{
    .{ .name = "Internet", .desc = "Internet Explorer", .path = "C:\\Program Files\\Internet Explorer\\iexplore.exe", .icon_id = 20, .column = .left_pinned, .item_type = .program, .bold = true, .arrow = false },
    .{ .name = "E-mail", .desc = "Outlook Express", .path = "C:\\Program Files\\Outlook Express\\msimn.exe", .icon_id = 21, .column = .left_pinned, .item_type = .program, .bold = true, .arrow = false },
};

pub const left_mfu: []const Row = &.{
    .{ .name = "Windows Media Player", .desc = "", .path = "C:\\Program Files\\Windows Media Player\\wmplayer.exe", .icon_id = 30, .column = .left_mfu, .item_type = .program, .bold = false, .arrow = false },
    .{ .name = "Command Prompt", .desc = "", .path = "C:\\WINDOWS\\system32\\cmd.exe", .icon_id = 31, .column = .left_mfu, .item_type = .program, .bold = false, .arrow = false },
    .{ .name = "Notepad", .desc = "", .path = "C:\\WINDOWS\\system32\\notepad.exe", .icon_id = 32, .column = .left_mfu, .item_type = .program, .bold = false, .arrow = false },
    .{ .name = "Paint", .desc = "", .path = "C:\\WINDOWS\\system32\\mspaint.exe", .icon_id = 33, .column = .left_mfu, .item_type = .program, .bold = false, .arrow = false },
    .{ .name = "Calculator", .desc = "", .path = "C:\\WINDOWS\\system32\\calc.exe", .icon_id = 34, .column = .left_mfu, .item_type = .program, .bold = false, .arrow = false },
    .{ .name = "", .desc = "", .path = "", .icon_id = 0, .column = .left_mfu, .item_type = .separator, .bold = false, .arrow = false },
    .{ .name = "All Programs", .desc = "", .path = "", .icon_id = 40, .column = .left_mfu, .item_type = .folder, .bold = false, .arrow = true },
};

pub const right: []const Row = &.{
    .{ .name = "My Documents", .desc = "", .path = "C:\\Documents and Settings\\User\\My Documents", .icon_id = 50, .column = .right, .item_type = .system_link, .bold = true, .arrow = false },
    .{ .name = "My Recent Documents", .desc = "", .path = "", .icon_id = 51, .column = .right, .item_type = .system_link, .bold = false, .arrow = true },
    .{ .name = "My Pictures", .desc = "", .path = "C:\\Documents and Settings\\User\\My Documents\\My Pictures", .icon_id = 52, .column = .right, .item_type = .system_link, .bold = false, .arrow = false },
    .{ .name = "My Music", .desc = "", .path = "C:\\Documents and Settings\\User\\My Documents\\My Music", .icon_id = 53, .column = .right, .item_type = .system_link, .bold = false, .arrow = false },
    .{ .name = "My Computer", .desc = "", .path = "C:\\", .icon_id = 54, .column = .right, .item_type = .system_link, .bold = true, .arrow = false },
    .{ .name = "", .desc = "", .path = "", .icon_id = 0, .column = .right, .item_type = .separator, .bold = false, .arrow = false },
    .{ .name = "Control Panel", .desc = "", .path = "C:\\WINDOWS\\system32\\control.exe", .icon_id = 60, .column = .right, .item_type = .system_link, .bold = false, .arrow = false },
    .{ .name = "Printers and Faxes", .desc = "", .path = "", .icon_id = 61, .column = .right, .item_type = .system_link, .bold = false, .arrow = false },
    .{ .name = "Help and Support", .desc = "", .path = "", .icon_id = 62, .column = .right, .item_type = .system_link, .bold = false, .arrow = false },
    .{ .name = "Search", .desc = "", .path = "", .icon_id = 63, .column = .right, .item_type = .system_link, .bold = false, .arrow = false },
    .{ .name = "Run...", .desc = "", .path = "", .icon_id = 64, .column = .right, .item_type = .system_link, .bold = false, .arrow = false },
};
