//! Minimal PNG decoder: 8-bit RGB or RGBA, non-interlaced. Uses std.compress.flate (zlib).

const std = @import("std");
const flate = std.compress.flate;
const Allocator = std.mem.Allocator;

pub const DecodedPng = struct {
    width: u32,
    height: u32,
    rgba: []u8,
    allocator: Allocator,

    pub fn deinit(self: *DecodedPng) void {
        self.allocator.free(self.rgba);
        self.* = undefined;
    }
};

fn readU32Be(b: []const u8, off: usize) error{Truncated}!u32 {
    if (off + 4 > b.len) return error.Truncated;
    return std.mem.readInt(u32, b[off..][0..4], .big);
}

pub fn decode(allocator: Allocator, file_bytes: []const u8) !DecodedPng {
    if (file_bytes.len < 8 + 12 + 13) return error.InvalidPng;
    if (!std.mem.eql(u8, file_bytes[0..8], &[_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }))
        return error.InvalidPng;

    var width: u32 = 0;
    var height: u32 = 0;
    var bit_depth: u8 = 0;
    var color_type: u8 = 0;

    var idat_list = std.ArrayListUnmanaged(u8){};
    defer idat_list.deinit(allocator);
    try idat_list.ensureTotalCapacity(allocator, 4096);

    var pos: usize = 8;
    while (pos + 12 <= file_bytes.len) {
        const chunk_len = try readU32Be(file_bytes, pos);
        pos += 4;
        if (pos + 8 + chunk_len > file_bytes.len) return error.Truncated;
        const chunk_type = file_bytes[pos..][0..4].*;
        pos += 4;
        const data_start = pos;
        pos += chunk_len;
        const crc_pos = pos;
        pos += 4;
        _ = crc_pos;

        if (std.mem.eql(u8, &chunk_type, "IHDR")) {
            if (chunk_len != 13) return error.InvalidPng;
            width = try readU32Be(file_bytes, data_start);
            height = try readU32Be(file_bytes, data_start + 4);
            bit_depth = file_bytes[data_start + 8];
            color_type = file_bytes[data_start + 9];
            const comp = file_bytes[data_start + 10];
            const filt = file_bytes[data_start + 11];
            const inter = file_bytes[data_start + 12];
            if (comp != 0 or filt != 0 or inter != 0) return error.UnsupportedPng;
            if (bit_depth != 8) return error.UnsupportedPng;
            if (color_type != 2 and color_type != 6) return error.UnsupportedPng; // RGB or RGBA
        } else if (std.mem.eql(u8, &chunk_type, "IDAT")) {
            try idat_list.appendSlice(allocator, file_bytes[data_start..][0..chunk_len]);
        } else if (std.mem.eql(u8, &chunk_type, "IEND")) {
            break;
        }
    }

    if (width == 0 or height == 0) return error.InvalidPng;
    const bpp: usize = if (color_type == 6) 4 else 3;
    const row_bytes = width * @as(u32, @intCast(bpp)) + 1;
    const raw_len = @as(usize, height) * @as(usize, row_bytes);

    var in_reader: std.Io.Reader = .fixed(idat_list.items);
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    var decompress: flate.Decompress = .init(&in_reader, .zlib, &.{});
    const inflated = try decompress.reader.streamRemaining(&aw.writer);
    if (inflated != raw_len) return error.InvalidPng;

    const raw = try aw.toOwnedSlice();
    defer allocator.free(raw);

    const out_px = @as(usize, width) * @as(usize, height) * 4;
    const rgba = try allocator.alloc(u8, out_px);
    errdefer allocator.free(rgba);

    const prior = try allocator.alloc(u8, width * @as(usize, bpp));
    defer allocator.free(prior);
    @memset(prior, 0);

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        const row_off = @as(usize, y) * @as(usize, row_bytes);
        const filt_type = raw[row_off];
        const row = raw[row_off + 1 .. row_off + row_bytes];

        var cur = try allocator.alloc(u8, width * @as(usize, bpp));
        defer allocator.free(cur);

        var i: usize = 0;
        while (i < row.len) : (i += 1) {
            const c = row[i];
            const left: u8 = if (i >= bpp) cur[i - bpp] else 0;
            const up: u8 = prior[i];
            const left_up: u8 = if (i >= bpp) prior[i - bpp] else 0;
            const recon: u8 = switch (filt_type) {
                0 => c,
                1 => c +% left,
                2 => c +% up,
                3 => c +% @as(u8, @intCast((@as(u16, left) + @as(u16, up)) / 2)),
                4 => c +% paeth(left, up, left_up),
                else => return error.UnsupportedPng,
            };
            cur[i] = recon;
        }

        var col: u32 = 0;
        while (col < width) : (col += 1) {
            const di = (@as(usize, y) * @as(usize, width) + col) * 4;
            const si = @as(usize, col) * bpp;
            if (bpp == 4) {
                rgba[di..][0..4].* = cur[si..][0..4].*;
            } else {
                rgba[di + 0] = cur[si + 0];
                rgba[di + 1] = cur[si + 1];
                rgba[di + 2] = cur[si + 2];
                rgba[di + 3] = 255;
            }
        }

        @memcpy(prior, cur);
    }

    return .{
        .width = width,
        .height = height,
        .rgba = rgba,
        .allocator = allocator,
    };
}

fn paeth(a: u8, b: u8, c: u8) u8 {
    const p = @as(i16, a) + @as(i16, b) - @as(i16, c);
    const pa = @abs(p - @as(i16, a));
    const pb = @abs(p - @as(i16, b));
    const pc = @abs(p - @as(i16, c));
    if (pa <= pb and pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

test "decode generated icon size" {
    const testing = std.testing;
    const path = "src/desktop/luna/resources/icons/system/icon_search.png";
    const f = try std.fs.cwd().openFile(path, .{});
    defer f.close();
    const bytes = try f.readToEndAlloc(testing.allocator, 1 << 20);
    defer testing.allocator.free(bytes);

    var dec = try decode(testing.allocator, bytes);
    defer dec.deinit();
    try testing.expectEqual(@as(u32, 32), dec.width);
    try testing.expectEqual(@as(u32, 32), dec.height);
    try testing.expectEqual(@as(usize, 32 * 32 * 4), dec.rgba.len);
}
