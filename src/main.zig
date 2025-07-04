const std = @import("std");
const zit = @import("zit.zig");

const version = "0.0-dev";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        //.stack_trace_frames = 16,
        .safety = true,
    }){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "init")) {
            try zit.initialize();
        } else if (std.mem.eql(u8, arg, "version")) {
            std.debug.print("{s}", .{version});
        } else if (std.mem.eql(u8, arg, "ls")) {
            _ = try zit.iterateFiles(alloc);
        } else if (std.mem.eql(u8, arg, "hash")) {
            if (args.len < i + 2) {
                std.debug.print("Not enought arguments for `hash`!\n", .{});
                continue;
            }
            const cacheOrNull = zit.checksumFile(alloc, try std.fs.cwd().openFile(args[i + 1], .{}));
            if (cacheOrNull) |cache| {
                for (cache) |byte| {
                    std.debug.print("{x}", .{byte});
                }
            } else {
                std.debug.print("No cache for you today!\n", .{});
            }
        }
    }
}
