//! VGA 文本模式 80×25（0xB8000），供 CMD 与内核提示。

const VGA_BASE: usize = 0xB8000;
const W: usize = 80;
const H: usize = 25;

pub const VGA_ADDR: *volatile [H][W]struct { char: u8, attr: u8 } = @ptrFromInt(VGA_BASE);

var cur_attr: u8 = 0x0F; // 白字黑底
var row: usize = 0;
var col: usize = 0;

pub fn setAttr(a: u8) void {
    cur_attr = a;
}

pub fn getAttr() u8 {
    return cur_attr;
}

pub fn clear() void {
    for (0..H) |r| {
        for (0..W) |c| {
            VGA_ADDR[r][c].char = ' ';
            VGA_ADDR[r][c].attr = cur_attr;
        }
    }
    row = 0;
    col = 0;
}

pub fn setCursor(r: usize, c: usize) void {
    row = @min(r, H - 1);
    col = @min(c, W - 1);
}

pub fn getCursor() struct { r: usize, c: usize } {
    return .{ .r = row, .c = col };
}

fn scroll() void {
    if (row < H) return;
    var r: usize = 1;
    while (r < H) : (r += 1) {
        var c: usize = 0;
        while (c < W) : (c += 1) {
            VGA_ADDR[r - 1][c] = VGA_ADDR[r][c];
        }
    }
    var c: usize = 0;
    while (c < W) : (c += 1) {
        VGA_ADDR[H - 1][c].char = ' ';
        VGA_ADDR[H - 1][c].attr = cur_attr;
    }
    row = H - 1;
}

pub fn putc(ch: u8) void {
    if (ch == '\r') {
        col = 0;
        return;
    }
    if (ch == '\n') {
        col = 0;
        row += 1;
        scroll();
        return;
    }
    if (col >= W) {
        col = 0;
        row += 1;
        scroll();
    }
    VGA_ADDR[row][col].char = ch;
    VGA_ADDR[row][col].attr = cur_attr;
    col += 1;
    if (col >= W) {
        col = 0;
        row += 1;
        scroll();
    }
}

pub fn puts(s: []const u8) void {
    for (s) |c| putc(c);
}

pub fn putcAt(r: usize, c: usize, ch: u8, attr: u8) void {
    if (r >= H or c >= W) return;
    VGA_ADDR[r][c].char = ch;
    VGA_ADDR[r][c].attr = attr;
}

pub fn putsAt(r: usize, c: usize, s: []const u8, attr: u8) void {
    var cc = c;
    for (s) |ch| {
        if (r >= H or cc >= W) break;
        VGA_ADDR[r][cc].char = ch;
        VGA_ADDR[r][cc].attr = attr;
        cc += 1;
    }
}
