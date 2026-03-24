//! Decoded PNG cache keyed by theme-relative path；带简单 LRU 上限。

const std = @import("std");
const png_lite = @import("png_lite.zig");

const Entry = struct {
    width: u32,
    height: u32,
    rgba: []u8,
};

const max_entries: usize = 64;

var g_alloc: ?std.mem.Allocator = null;
var map: std.StringHashMapUnmanaged(Entry) = .empty;
/// 最近使用顺序（队尾 = 最新）；键与 map 中相同指针。
var lru_order: std.ArrayListUnmanaged([]const u8) = .empty;

pub fn init(allocator: std.mem.Allocator) void {
    g_alloc = allocator;
}

pub fn deinit() void {
    clear();
    const a = g_alloc orelse return;
    lru_order.deinit(a);
    lru_order = .empty;
    g_alloc = null;
}

fn touchKey(key: []const u8) void {
    const a = g_alloc orelse return;
    var i: usize = 0;
    while (i < lru_order.items.len) : (i += 1) {
        if (std.mem.eql(u8, lru_order.items[i], key)) {
            const k = lru_order.orderedRemove(i);
            lru_order.append(a, k) catch return;
            return;
        }
    }
}

fn evictOldest() void {
    const a = g_alloc orelse return;
    if (lru_order.items.len == 0) return;
    const victim = lru_order.orderedRemove(0);
    if (map.fetchRemove(victim)) |kv| {
        a.free(kv.key);
        a.free(kv.value.rgba);
    }
}

pub fn clear() void {
    const a = g_alloc orelse return;
    var it = map.iterator();
    while (it.next()) |kv| {
        a.free(kv.key_ptr.*);
        a.free(kv.value_ptr.rgba);
    }
    map.deinit(a);
    map = .empty;
    lru_order.clearRetainingCapacity();
}

pub const BitmapView = struct {
    width: u32,
    height: u32,
    rgba: []const u8,
};

/// Returns view into cache; valid until `clear` / `deinit` / theme reload.
pub fn getOrLoad(theme_root: []const u8, rel_path: []const u8) ?BitmapView {
    const a = g_alloc orelse return null;
    if (theme_root.len == 0) return null;

    if (map.get(rel_path)) |e| {
        touchKey(rel_path);
        return .{ .width = e.width, .height = e.height, .rgba = e.rgba };
    }

    while (map.count() >= max_entries) {
        evictOldest();
    }

    const joined = std.fs.path.join(a, &.{ theme_root, rel_path }) catch return null;
    defer a.free(joined);

    const file = std.fs.cwd().openFile(joined, .{}) catch return null;
    defer file.close();
    return loadFromOpenedFile(a, rel_path, file) catch null;
}

fn loadFromOpenedFile(a: std.mem.Allocator, rel_path: []const u8, file: std.fs.File) !BitmapView {
    const bytes = try file.readToEndAlloc(a, 32 * 1024 * 1024);
    defer a.free(bytes);
    var dec = try png_lite.decode(a, bytes);
    defer dec.deinit();

    const key = try a.dupe(u8, rel_path);
    errdefer a.free(key);

    const rgba = try a.dupe(u8, dec.rgba);
    errdefer a.free(rgba);

    try map.put(a, key, .{
        .width = dec.width,
        .height = dec.height,
        .rgba = rgba,
    });
    try lru_order.append(a, key);

    const e = map.getPtr(key).?;
    return .{ .width = e.width, .height = e.height, .rgba = e.rgba };
}

pub fn cursorHotspot(which: enum { arrow, wait }) struct { x: u32, y: u32 } {
    return switch (which) {
        .arrow => .{ .x = 1, .y = 1 },
        .wait => .{ .x = 16, .y = 16 },
    };
}
