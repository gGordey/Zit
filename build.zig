const std = @import("std");

pub fn build(b: *std.Build) void {
    const final_exe = b.addExecutable(.{
        .name = "zit",
        .root_source_file = b.path("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    b.installArtifact(final_exe);
}
