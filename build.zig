const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library creation.
    const lib_module = b.addLibrary(.{
        .name = "codata",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Install (write) the library to zig-out/bin.
    b.installArtifact(lib_module);
}
