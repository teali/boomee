const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zaudio_dep = b.dependency("zaudio", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "sine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addImport("zaudio", zaudio_dep.module("root"));

    // This links the compiled miniaudio artifact that zaudio provides.
    exe.linkLibrary(zaudio_dep.artifact("miniaudio"));

    // libc is required.
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the sine demo");
    run_step.dependOn(&run_cmd.step);
}
