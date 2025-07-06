const std = @import("std");
const fs = std.fs;

const ZitFileCache = struct {
    filename: []const u8,
    file: fs.File,
};

pub const FileHandle = struct {
    file: fs.File,
    text: ?[]u8,
    alloc: std.mem.Allocator,
    pub fn init(alloc: std.mem.Allocator, path: []const u8) !FileHandle {
        var handle: FileHandle = undefined;

        handle.file = try fs.cwd().openFile(path, .{
            .mode = .read_write,
        });
        handle.text = try alloc.alloc(u8, try handle.file.getEndPos());
        _ = try handle.file.read(handle.text.?);

        handle.alloc = alloc;

        return handle;
    }
    pub fn deinit(self: *FileHandle) void {
        self.file.close();
        if (self.text) |text| {
            self.alloc.free(text);
        }
    }
    pub fn initOverride(alloc: std.mem.Allocator, path: []const u8) !FileHandle {
        var handle: FileHandle = undefined;

        handle.file = try fs.cwd().createFile(path, .{});
        handle.text = null;
        handle.alloc = alloc;

        return handle;
    }
};
pub fn initialize() !void {
    try fs.cwd().makeDir(".zit");
    try fs.cwd().makeDir(".zit/main");
}

fn readIngoreFile(alloc: std.mem.Allocator, file: FileHandle) ?std.ArrayList([]const u8) {
    var result_list = std.ArrayList([]const u8).init(alloc);

    var text: []const u8 = undefined;

    if (file.text) |file_text| {
        text = file_text;
    } else return null;

    var l: usize = 0;
    var r: usize = 0;
    while (r < text.len) : (r += 1) {
        if (text[r] == '\n' and r - l > 1) {
            const entry_len = r - l - 1;
            const ignore_item = alloc.alloc(u8, entry_len) catch return null;
            std.mem.copyForwards(u8, ignore_item, text[l .. r - 1]); // -1 cuz \n is included
            result_list.append(ignore_item) catch return null;
            l = r + 1;
        }
    }
    return result_list;
}

fn ingoteFile(alloc: std.mem.Allocator, path: []const u8, zitignore_file: FileHandle) bool {
    if (path.len < 4) return false;
    if (std.mem.eql(u8, path[0..4], ".zit")) return true;

    if (readIngoreFile(alloc, zitignore_file)) |ignore_list| {
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

    var zitignore_file = try FileHandle.init(alloc, ".zitignore");
    defer zitignore_file.deinit();

    while (try dir_walker.next()) |item| {
        if (ingoteFile(alloc, item.path, zitignore_file)) continue;

        std.debug.print("{s} --- {s}\n", .{ if (item.kind == .file) "f" else "d", item.path });
    }
}
pub fn replaceText(alloc: std.mem.Allocator, path: []const u8, find: []const u8, replace: []const u8) !void {
    var file = try FileHandle.initOverride(alloc, path);
    defer file.deinit();

    _ = try file.file.write("HAHAHAHAHAH");

    _ = .{ find, replace };
}
pub fn cacheFile(file: fs.File) ZitFileCache {
    _ = file;
}
pub fn checksumFile(alloc: std.mem.Allocator, path: []const u8) ?[32]u8 {
    var file = FileHandle.init(alloc, path) catch return null;
    defer file.deinit();

    var hash = std.crypto.hash.sha2.Sha256.init(.{});

    hash.update(file.text.?);

    var final: [32]u8 = undefined;
    hash.final(&final);

    return final;
}
