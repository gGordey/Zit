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
fn iterateFiles(alloc: std.mem.Allocator, callback: fn (entry: fs.Dir.Walker.Entry, args: anytype) anyerror!void, args: anytype) !void {
    var dir = try fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var dir_walker = try dir.walk(alloc);
    defer dir_walker.deinit();

    while (try dir_walker.next()) |item| try callback(item, args);
}
fn listFileCallback(entry: fs.Dir.Walker.Entry, args: anytype) !void {
    if (args.ignore_file) |zitignore| {
        if (ingoteFile(args.alloc, entry.path, zitignore)) return;
    }
    std.debug.print("{s} --- {s}\n", .{ if (entry.kind == .file) "f" else "d", entry.path });
}
pub fn listFiles(alloc: std.mem.Allocator) !void {
    var ignore_file = FileHandle.init(alloc, ".zitignore") catch null;
    defer if (ignore_file) |*zitignore| {
        zitignore.deinit();
    };
    try iterateFiles(alloc, listFileCallback, .{ .ignore_file = ignore_file, .alloc = alloc });
}
fn findCallback(entry: fs.Dir.Walker.Entry, args: anytype) !void {
    if (entry.kind == .directory) return;

    var entry_file = FileHandle.init(args.alloc, entry.path) catch |err| {
        std.debug.print("! Error: {} in path {s}\n", .{ err, entry.path });
        return;
    };
    defer entry_file.deinit();

    var i: usize = 0;
    var line: usize = 0;
    var match_count: usize = 0;
    while (i < entry_file.text.?.len) : (i += 1) {
        if (entry_file.text.?[i] == '\n') line += 1;

        if (entry_file.text.?[i] == args.find[match_count]) {
            match_count += 1;
        } else {
            match_count = 0;
        }

        if (match_count == args.find.len) {
            match_count = 0;
            std.debug.print("\"{s}\" {} | {s}\n", .{ entry.path, line, args.find });
        }
    }
}
pub fn findText(alloc: std.mem.Allocator, find: []const u8) !void {
    try iterateFiles(alloc, findCallback, .{ .find = find, .alloc = alloc });
}
fn replaceTextCallback(entry: fs.Dir.Walker.Entry, args: anytype) !void {
    if (entry.kind == .directory) return;

    var read_handle = FileHandle.init(args.alloc, entry.path) catch |err| {
        std.debug.print("! Error: {} in path {s}\n", .{ err, entry.path });
        return;
    };
    const text_len = read_handle.text.?.len;

    const text_buf = args.alloc.alloc(u8, text_len) catch |err| {
        read_handle.deinit();
        return err;
    };
    defer args.alloc.free(text_buf);

    std.mem.copyForwards(u8, text_buf, read_handle.text.?);
    read_handle.deinit();

    var target_file = try FileHandle.initOverride(args.alloc, entry.path);
    defer target_file.deinit();

    var i: usize = 0;
    var match_count: usize = 0;
    while (i < text_len) : (i += 1) {
        if (text_buf[i] == args.find[match_count]) {
            match_count += 1;
        } else {
            _ = try target_file.file.write(text_buf[i - match_count .. i + 1]); //save match_count is maximum i
            match_count = 0;
        }

        if (match_count == args.find.len) {
            match_count = 0;
            std.debug.print("\"{s}\" `{s}` -> `{s}`\n", .{ entry.path, args.find, args.replace });
            _ = try target_file.file.write(args.replace);
        }
    }
}
pub fn replaceText(alloc: std.mem.Allocator, find: []const u8, replace: []const u8) !void {
    try iterateFiles(alloc, replaceTextCallback, .{ .find = find, .replace = replace, .alloc = alloc });
}
pub fn hashFile(alloc: std.mem.Allocator, path: []const u8) ?[32]u8 {
    var file = FileHandle.init(alloc, path) catch return null;
    defer file.deinit();

    var hash = std.crypto.hash.sha2.Sha256.init(.{});

    hash.update(file.text.?);

    var final: [32]u8 = undefined;
    hash.final(&final);

    return final;
}
