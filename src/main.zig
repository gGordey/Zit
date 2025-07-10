const std = @import("std");
const zit = @import("zit.zig");

const version = "0.2-dev";

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
        } else if (std.mem.eql(u8, arg, "version") or std.mem.eql(u8, arg, "--version")) {
            std.debug.print("{s}", .{version});
        } else if (std.mem.eql(u8, arg, "ls")) {
            _ = try zit.listFiles(alloc);
        } else if (std.mem.eql(u8, arg, "hash")) {
            if (args.len < i + 2) {
                std.debug.print("Not enought arguments for `hash`!\n", .{});
                continue;
            }
            if (zit.hashFile(alloc, args[i + 1])) |cache| {
                for (cache) |byte| {
                    std.debug.print("{x}", .{byte});
                }
            } else {
                std.debug.print("No hash for you today!\n", .{});
            }
        } else if (std.mem.eql(u8, arg, "replace")) {
            if (args.len < i + 3) {
                std.debug.print("Not enought arguments for `replace`!\n", .{});
                continue;
            }
            zit.replaceText(alloc, args[i + 1], args[i + 2]) catch |err| {
                std.debug.print("OOHH NOO", .{});
                return err;
            };
        } else if (std.mem.eql(u8, arg, "find")) {
            if (args.len < i + 2) {
                std.debug.print("Not enought arguments for `find`\n", .{});
                continue;
            }
            zit.findText(alloc, args[i + 1]) catch |err| {
                std.debug.print("OOHH NOO", .{});
                return err;
            };
        }
    }
}
