//! 内核态 CMD 风格解释器（VGA 文本 + PS/2 + 串口镜像）。非 Windows cmd.exe。

const kver = @import("build_config").kernel_line;
const vga = @import("../hal/vga_text.zig");
const kbd = @import("../hal/kbd.zig");
const serial = @import("../hal/serial.zig");
const port = @import("../hal/port.zig");
const pmm = @import("../mm/pmm.zig");

const line_cap = 256;
const max_args = 16;

var line_buf: [line_cap]u8 = undefined;
var line_len: usize = 0;

var prompt_buf: [48]u8 = undefined;
var prompt_len: usize = 0;

var title_buf: [80]u8 = undefined;
var title_len: usize = 0;

var cwd_buf: [64]u8 = undefined;
var cwd_len: usize = 0;

fn initShellStrings() void {
    const p = "C:\\ZirconOS> ";
    @memcpy(prompt_buf[0..p.len], p);
    prompt_len = p.len;

    const t = "ZirconOSLuna CMD [kernel]";
    @memcpy(title_buf[0..t.len], t);
    title_len = t.len;

    const c = "C:\\";
    @memcpy(cwd_buf[0..c.len], c);
    cwd_len = c.len;
}

fn rdtsc() u64 {
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    asm volatile ("rdtsc"
        : [lo] "={eax}" (lo),
          [hi] "={edx}" (hi),
        :
        : .{ .memory = true });
    return (@as(u64, hi) << 32) | @as(u64, lo);
}

fn mirrorSerial(s: []const u8) void {
    serial.writeStr(s);
}

fn mirrorSerialByte(c: u8) void {
    serial.writeByte(c);
}

pub fn run() void {
    initShellStrings();
    kbd.init();
    vga.clear();
    vga.setAttr(0x1F); // 白底蓝字标题行
    drawTitleBar();
    vga.setAttr(0x0F);
    vga.puts("\r\n");
    vga.puts("ZirconOSLuna CMD — type HELP\r\n");
    mirrorSerial("ZirconOSLuna CMD — type HELP\r\n");

    while (true) {
        vga.setAttr(0x0F);
        vga.puts(prompt_buf[0..prompt_len]);
        mirrorSerial(prompt_buf[0..prompt_len]);
        line_len = 0;
        var line_done = false;
        while (!line_done) {
            if (kbd.pollKey()) |ch| {
                if (ch == '\r') {
                    vga.putc('\r');
                    vga.putc('\n');
                    mirrorSerial("\r\n");
                    line_buf[line_len] = 0;
                    dispatch(line_buf[0..line_len]);
                    line_done = true;
                    continue;
                }
                if (ch == 0x08) { // backspace
                    if (line_len > 0) {
                        line_len -= 1;
                        vga.putc(0x08);
                        vga.putc(' ');
                        vga.putc(0x08);
                        mirrorSerialByte(0x08);
                        mirrorSerialByte(' ');
                        mirrorSerialByte(0x08);
                    }
                    continue;
                }
                if (line_len + 1 < line_cap) {
                    line_buf[line_len] = ch;
                    line_len += 1;
                    vga.putc(ch);
                    mirrorSerialByte(ch);
                }
            } else {
                asm volatile ("pause" ::: .{ .memory = true });
            }
        }
    }
}

fn drawTitleBar() void {
    var i: usize = 0;
    while (i < 80) : (i += 1) {
        vga.putcAt(0, i, ' ', 0x1F);
    }
    vga.putsAt(0, 0, title_buf[0..title_len], 0x1F);
}

fn dispatch(raw: []const u8) void {
    var trimmed = raw;
    while (trimmed.len > 0 and trimmed[0] == ' ') trimmed = trimmed[1..];
    while (trimmed.len > 0 and trimmed[trimmed.len - 1] == ' ') trimmed = trimmed[0 .. trimmed.len - 1];
    if (trimmed.len == 0) return;

    var args: [max_args][]const u8 = undefined;
    var argc: usize = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= trimmed.len) : (i += 1) {
        const at_end = i == trimmed.len;
        const sp = !at_end and trimmed[i] == ' ';
        if (at_end or sp) {
            if (i > start and argc < max_args) {
                args[argc] = trimmed[start..i];
                argc += 1;
            }
            start = i + 1;
        }
    }
    if (argc == 0) return;

    const cmd = args[0];
    if (eqlIgnoreCase(cmd, "help") or eqlIgnoreCase(cmd, "?")) {
        cmdHelp();
    } else if (eqlIgnoreCase(cmd, "cls")) {
        cmdCls();
    } else if (eqlIgnoreCase(cmd, "ver")) {
        cmdVer();
    } else if (eqlIgnoreCase(cmd, "echo")) {
        cmdEcho(args[1..argc]);
    } else if (eqlIgnoreCase(cmd, "color")) {
        cmdColor(args[1..argc]);
    } else if (eqlIgnoreCase(cmd, "prompt")) {
        cmdPrompt(args[1..argc]);
    } else if (eqlIgnoreCase(cmd, "title")) {
        cmdTitle(args[1..argc]);
    } else if (eqlIgnoreCase(cmd, "mem")) {
        cmdMem();
    } else if (eqlIgnoreCase(cmd, "pwd")) {
        cmdPwd();
    } else if (eqlIgnoreCase(cmd, "cd")) {
        cmdCd(args[1..argc]);
    } else if (eqlIgnoreCase(cmd, "dir")) {
        cmdDir();
    } else if (eqlIgnoreCase(cmd, "type")) {
        cmdType(args[1..argc]);
    } else if (eqlIgnoreCase(cmd, "uptime")) {
        cmdUptime();
    } else if (eqlIgnoreCase(cmd, "reboot")) {
        cmdReboot();
    } else if (eqlIgnoreCase(cmd, "exit") or eqlIgnoreCase(cmd, "quit")) {
        cmdExit();
    } else {
        outLn("Bad command or file name.");
    }
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |ca, idx| {
        const cb = b[idx];
        const la = if (ca >= 'A' and ca <= 'Z') ca + 32 else ca;
        const lb = if (cb >= 'A' and cb <= 'Z') cb + 32 else cb;
        if (la != lb) return false;
    }
    return true;
}

fn outLn(s: []const u8) void {
    vga.puts(s);
    vga.puts("\r\n");
    mirrorSerial(s);
    mirrorSerial("\r\n");
}

fn cmdHelp() void {
    outLn("Commands:");
    outLn("  HELP       - This list");
    outLn("  CLS        - Clear screen");
    outLn("  VER        - Version");
    outLn("  ECHO text  - Print text");
    outLn("  COLOR fg [bg] - VGA color 0-15");
    outLn("  PROMPT str - Set prompt");
    outLn("  TITLE str  - Title bar");
    outLn("  MEM        - PMM pool bytes left");
    outLn("  PWD        - Current directory");
    outLn("  CD path    - Change directory (stub)");
    outLn("  DIR        - List files (stub)");
    outLn("  TYPE file  - Show file (stub)");
    outLn("  UPTIME     - TSC ticks");
    outLn("  REBOOT     - Reset via 0xCF9");
    outLn("  EXIT       - Halt CPU");
}

fn cmdCls() void {
    vga.clear();
    drawTitleBar();
    vga.setAttr(0x0F);
    vga.setCursor(2, 0);
}

fn cmdVer() void {
    outLn("ZirconOSLuna Kernel CMD");
    outLn(kver);
}

fn cmdEcho(rest: []const []const u8) void {
    var first = true;
    for (rest) |w| {
        if (!first) {
            vga.putc(' ');
            mirrorSerialByte(' ');
        }
        first = false;
        vga.puts(w);
        mirrorSerial(w);
    }
    outLn("");
}

fn parseU8(s: []const u8) ?u8 {
    if (s.len == 0) return null;
    var v: u16 = 0;
    for (s) |c| {
        if (c < '0' or c > '9') return null;
        v = v * 10 + (c - '0');
        if (v > 255) return null;
    }
    return @truncate(v);
}

fn cmdColor(rest: []const []const u8) void {
    if (rest.len == 0) {
        outLn("COLOR fg [bg]  (0-15)");
        return;
    }
    const fg = parseU8(rest[0]) orelse {
        outLn("Invalid fg.");
        return;
    };
    const bg: u8 = if (rest.len > 1) (parseU8(rest[1]) orelse 0) else 0;
    if (fg > 15 or bg > 15) {
        outLn("Range 0-15.");
        return;
    }
    const attr: u8 = @truncate((bg << 4) | fg);
    vga.setAttr(attr);
    outLn("Color applied.");
}

fn cmdPrompt(rest: []const []const u8) void {
    if (rest.len == 0) {
        outLn("PROMPT text");
        return;
    }
    var len: usize = 0;
    var first = true;
    for (rest) |w| {
        if (!first and len + 1 < prompt_buf.len) {
            prompt_buf[len] = ' ';
            len += 1;
        }
        first = false;
        for (w) |c| {
            if (len + 1 >= prompt_buf.len) break;
            prompt_buf[len] = c;
            len += 1;
        }
    }
    prompt_len = len;
}

fn cmdTitle(rest: []const []const u8) void {
    if (rest.len == 0) return;
    var len: usize = 0;
    var first = true;
    for (rest) |w| {
        if (!first and len + 1 < title_buf.len) {
            title_buf[len] = ' ';
            len += 1;
        }
        first = false;
        for (w) |c| {
            if (len + 1 >= title_buf.len) break;
            title_buf[len] = c;
            len += 1;
        }
    }
    title_len = len;
    drawTitleBar();
}

fn cmdMem() void {
    const r = pmm.poolRemainingBytes();
    vga.puts("PMM bytes free: ");
    mirrorSerial("PMM bytes free: ");
    writeU64Dec(r);
    outLn("");
}

fn writeU64Dec(v: u64) void {
    if (v == 0) {
        vga.putc('0');
        mirrorSerialByte('0');
        return;
    }
    var buf: [20]u8 = undefined;
    var n = v;
    var i: usize = buf.len;
    while (n > 0) {
        i -= 1;
        buf[i] = @truncate('0' + (n % 10));
        n /= 10;
    }
    const s = buf[i..];
    vga.puts(s);
    mirrorSerial(s);
}

fn cmdPwd() void {
    outLn(cwd_buf[0..cwd_len]);
}

fn cmdCd(rest: []const []const u8) void {
    if (rest.len == 0) {
        const c = "C:\\";
        @memcpy(cwd_buf[0..c.len], c);
        cwd_len = c.len;
        outLn("C:\\");
        return;
    }
    outLn("CD: 完整路径解析尚未实现（stub）。");
}

fn cmdDir() void {
    outLn(" Volume in drive C is ZIRCONOSLUNA");
    outLn(" Directory of C:\\");
    outLn("");
    outLn("               0 File(s)              0 bytes");
    outLn("               0 Dir(s)      (stub)");
}

fn cmdType(rest: []const []const u8) void {
    if (rest.len == 0) {
        outLn("The syntax of the command is incorrect.");
        return;
    }
    outLn("TYPE: file I/O not implemented.");
}

fn cmdUptime() void {
    const t = rdtsc();
    vga.puts("TSC: 0x");
    mirrorSerial("TSC: 0x");
    writeHex64(t);
    outLn("");
}

fn writeHex64(v: u64) void {
    var buf: [16]u8 = undefined;
    var x = v;
    var i: usize = 16;
    while (i > 0) {
        i -= 1;
        const d: u8 = @truncate(x & 0xF);
        buf[i] = if (d < 10) '0' + d else 'a' + (d - 10);
        x >>= 4;
    }
    vga.puts(&buf);
    mirrorSerial(&buf);
}

fn cmdReboot() void {
    outLn("Rebooting...");
    // 8042 reset pulse
    port.outb(0x64, 0xFE);
    hang();
}

fn cmdExit() void {
    outLn("Halting...");
    hang();
}

fn hang() noreturn {
    cli();
    while (true) {
        asm volatile ("hlt" ::: .{ .memory = true });
    }
}

fn cli() void {
    asm volatile ("cli" ::: .{ .memory = true });
}
