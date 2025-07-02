const std = @import("std");
const fs = std.fs;

const ZitFileCache = struct {
    filename: []const u8,
    file: fs.File,
};
fn readIngoreFile(alloc: std.mem.Allocator) ?std.ArrayList([]const u8) {
    var file = fs.cwd().openFile(".zitignore", .{}) catch return null;
    defer file.close();

    const end_pos = file.getEndPos() catch return null;
    var file_text_buf = alloc.alloc(u8, end_pos) catch return null;
    defer alloc.free(file_text_buf);

    _ = file.read(file_text_buf) catch return null;

    var result_list = std.ArrayList([]const u8).init(alloc);

    var l: usize = 0;
    var r: usize = 0;
    while (r < end_pos) : (r += 1) {
        if (file_text_buf[r] == '\n' and r - l > 1) {
            const entry_len = r - l - 1;
            const ignore_item = alloc.alloc(u8, entry_len) catch return null;
            std.mem.copyForwards(u8, ignore_item, file_text_buf[l .. r - 1]); // -1 cuz \n is included
            result_list.append(ignore_item) catch return null;
            l = r + 1;
        }
    }
    return result_list;
}
pub fn initialize() !void {
    try fs.cwd().makeDir(".zit");
    try fs.cwd().makeDir(".zit/main");
}
fn ingoteFile(alloc: std.mem.Allocator, path: []const u8) bool {
    if (path.len < 4) return false;
    if (std.mem.eql(u8, path[0..4], ".zit")) return true;

    if (readIngoreFile(alloc)) |ignore_list| {
        defer {
            for (ignore_list.items) |item| {
                alloc.free(item);
            }
            ignore_list.deinit();
        }
        for (ignore_list.items) |item| {
            if (path.len < item.len) continue;
            if (std.mem.eql(u8, item, path[0..item.len])) return true;
        }
    }

    return false;
}
pub fn iterateFiles(alloc: std.mem.Allocator) !void {
    var dir = try fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var dir_walker = try dir.walk(alloc);
    defer dir_walker.deinit();

    while (try dir_walker.next()) |item| {
        if (ingoteFile(alloc, item.path)) continue;
        std.debug.print("{s} --- {s}\n", .{ if (item.kind == .file) "f" else "d", item.path });
    }
}
pub fn createZitFileCache(filename: []const u8) !ZitFileCache {
    var file = try fs.cwd().openFile(filename, .{});
    defer file.close();

    return ZitFileCache{
        .filename = filename,
        .file = file,
    };
}
