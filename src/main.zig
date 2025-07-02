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

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "init")) {
            try zit.initialize();
        } else if (std.mem.eql(u8, arg, "version")) {
            std.debug.print("{s}", .{version});
        }
        try zit.iterateFiles(alloc);
    }
}
