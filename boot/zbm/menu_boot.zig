//! Windows XP 风格启动菜单：GOP 只画一次 Luna 标题条 + 灰客户区；选项用 ConOut 前景/背景高亮。
//! 不再每 50ms 整屏 clear + GOP 条，避免蓝条与文字不同步的闪烁。

const std = @import("std");
const uefi = std.os.uefi;
const zbm_ini = @import("zbm_ini.zig");
const menu_gfx = @import("menu_gfx.zig");

const Attr = uefi.protocol.SimpleTextOutput.Attribute;

pub fn outputAscii(con_out: *uefi.protocol.SimpleTextOutput, s: []const u8) void {
    var tmp: [256:0]u16 = undefined;
    @memset(&tmp, 0);
    const n = @min(s.len, tmp.len - 1);
    for (0..n) |i| tmp[i] = s[i];
    tmp[n] = 0;
    _ = con_out.outputString(@ptrCast(&tmp)) catch {};
}

fn writeLine(con_out: *uefi.protocol.SimpleTextOutput, row: *usize, attr: Attr, text: []const u8) void {
    _ = con_out.setAttribute(attr) catch {};
    _ = con_out.setCursorPosition(0, row.*) catch {};
    outputAscii(con_out, text);
    outputAscii(con_out, "\r\n");
    row.* += 1;
}

fn padRow(con_out: *uefi.protocol.SimpleTextOutput, cols: usize, row: usize) void {
    var buf: [132]u8 = undefined;
    const w = @min(cols, buf.len - 2);
    @memset(buf[0..w], ' ');
    buf[w] = '\r';
    buf[w + 1] = '\n';
    _ = con_out.setCursorPosition(0, row) catch {};
    outputAscii(con_out, buf[0 .. w + 2]);
}

fn paintTimeoutOnly(
    con_out: *uefi.protocol.SimpleTextOutput,
    row: usize,
    cols: usize,
    remaining_us: u64,
) void {
    const sec = remaining_us / 1_000_000;
    var buf: [96]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "The highlighted choice starts automatically in {d} second(s).", .{sec}) catch return;
    padRow(con_out, cols, row);
    _ = con_out.setAttribute(.{ .foreground = .black, .background = .lightgray }) catch {};
    _ = con_out.setCursorPosition(0, row) catch {};
    outputAscii(con_out, msg);
    outputAscii(con_out, "\r\n");
}

/// 完整重绘文本层。返回超时提示所在行（无超时则 null）。
/// `clearScreen` 在部分固件上会清 GOP 帧缓冲，故在清屏后立刻重画 XP 底图。
fn paintMenuText(
    con_out: *uefi.protocol.SimpleTextOutput,
    cfg: *const zbm_ini.Parsed,
    active_idx: []const u32,
    sel: u32,
    remaining_us: u64,
    cols: usize,
    gop: ?*uefi.protocol.GraphicsOutput,
) ?usize {
    _ = con_out.clearScreen() catch {};
    if (cfg.gfx_menu) {
        if (gop) |g| {
            menu_gfx.paintXpChrome(g);
        }
    }

    var row: usize = 0;

    // 标题区：白字 + 蓝底（与 GOP Luna 条视觉一致）
    writeLine(con_out, &row, .{ .foreground = .white, .background = .blue }, "ZirconOS Boot Manager");
    writeLine(con_out, &row, .{ .foreground = .white, .background = .blue }, "Please select the operating system to start:");
    writeLine(con_out, &row, .{ .foreground = .white, .background = .blue }, "");

    if (cfg.profile_len > 0) {
        writeLine(con_out, &row, .{ .foreground = .lightgray, .background = .blue }, cfg.profile_line[0..cfg.profile_len]);
        writeLine(con_out, &row, .{ .foreground = .white, .background = .blue }, "");
    }

    if (!cfg.brief_menu) {
        writeLine(con_out, &row, .{ .foreground = .lightgray, .background = .blue }, "This program loads x86_64 Multiboot2 kernels only (e_machine=62).");
        writeLine(con_out, &row, .{ .foreground = .white, .background = .blue }, "");
    }

    // 客户区：XP 列表（未选：黑字灰底；选中：白字蓝底，仿资源管理器选中条）
    const n_act: u32 = @intCast(active_idx.len);
    var j: u32 = 0;
    while (j < n_act) : (j += 1) {
        const slot = active_idx[j];
        const title = cfg.entries[slot].title;
        const attr: Attr = if (j == sel)
            .{ .foreground = .white, .background = .blue }
        else
            .{ .foreground = .black, .background = .lightgray };

        var line_buf: [zbm_ini.subtitle_line_cap + 16]u8 = undefined;
        const mark: []const u8 = if (j == sel) "  * " else "    ";
        const printed = std.fmt.bufPrint(&line_buf, "{s}{c}) {s}", .{
            mark,
            @as(u8, @intCast('1' + j)),
            title,
        }) catch continue;
        writeLine(con_out, &row, attr, printed);
    }

    writeLine(con_out, &row, .{ .foreground = .black, .background = .lightgray }, "");
    writeLine(con_out, &row, .{ .foreground = .black, .background = .lightgray },
        "Use the UP and DOWN arrow keys to move the highlight. Press ENTER to boot.");
    writeLine(con_out, &row, .{ .foreground = .black, .background = .lightgray },
        "Keys 1-8 jump directly to an entry.");

    if (cfg.timeout_sec > 0) {
        const tr = row;
        paintTimeoutOnly(con_out, tr, cols, remaining_us);
        return tr;
    }
    return null;
}

/// 返回 **物理槽位** `entries[i]` 的下标 `i`。
pub fn run(
    st: *uefi.tables.SystemTable,
    bs: *uefi.tables.BootServices,
    cfg: *const zbm_ini.Parsed,
    gop: ?*uefi.protocol.GraphicsOutput,
) u32 {
    const con_out = st.con_out.?;
    const con_in = st.con_in;

    _ = con_out.enableCursor(false) catch {};

    const text_geom = con_out.queryMode(con_out.mode.mode) catch uefi.protocol.SimpleTextOutput.Geometry{
        .columns = 80,
        .rows = 25,
    };
    const cols = text_geom.columns;

    var active_idx: [zbm_ini.max_entries]u32 = undefined;
    const n_act = zbm_ini.collectActiveIndices(cfg, &active_idx);
    if (n_act == 0) return 0;

    var sel: u32 = cfg.default_index;
    if (sel >= n_act) sel = 0;

    var remaining_us: u64 = @as(u64, cfg.timeout_sec) * 1_000_000;
    const poll_us: u64 = 50_000;
    var user_moved = false;

    var dirty = true;
    var timeout_row: ?usize = null;
    var prev_shown_sec: u64 = std.math.maxInt(u64);

    while (true) {
        if (dirty) {
            timeout_row = paintMenuText(con_out, cfg, active_idx[0..n_act], sel, remaining_us, cols, gop);
            dirty = false;
            if (cfg.timeout_sec > 0) {
                prev_shown_sec = remaining_us / 1_000_000;
            }
        } else if (cfg.timeout_sec > 0) {
            const sec = remaining_us / 1_000_000;
            if (timeout_row) |tr| {
                if (sec != prev_shown_sec) {
                    paintTimeoutOnly(con_out, tr, cols, remaining_us);
                    prev_shown_sec = sec;
                }
            }
        }

        var waited: u64 = 0;
        poll_loop: while (waited < poll_us) {
            if (con_in) |cin| {
                const key = cin.readKeyStroke() catch |e| switch (e) {
                    error.NotReady => {
                        bs.stall(10_000) catch {};
                        waited += 10_000;
                        continue :poll_loop;
                    },
                    else => {
                        bs.stall(10_000) catch {};
                        waited += 10_000;
                        continue :poll_loop;
                    },
                };

                user_moved = true;
                remaining_us = @as(u64, cfg.timeout_sec) * 1_000_000;

                if (key.unicode_char == '\r') {
                    return active_idx[sel];
                }
                if (key.scan_code == 1) {
                    if (sel > 0) sel -= 1 else sel = n_act - 1;
                    dirty = true;
                    continue;
                }
                if (key.scan_code == 2) {
                    sel = (sel + 1) % n_act;
                    dirty = true;
                    continue;
                }
                const uc = key.unicode_char;
                if (uc >= '1' and uc <= '8') {
                    const d: u32 = @intCast(uc - '1');
                    if (d < n_act) {
                        sel = d;
                        return active_idx[sel];
                    }
                }
            } else {
                bs.stall(poll_us) catch {};
                waited = poll_us;
                break :poll_loop;
            }
        }

        remaining_us -|= poll_us;
        if (cfg.timeout_sec > 0 and remaining_us == 0 and !user_moved) {
            return active_idx[sel];
        }
    }
}
