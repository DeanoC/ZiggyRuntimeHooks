const std = @import("std");

fn requireSubmodule(b: *std.Build, path: []const u8) void {
    const absolute_path = b.pathFromRoot(path);
    std.fs.accessAbsolute(absolute_path, .{}) catch {
        std.process.fatal(
            "missing required first-party dependency at '{s}'. Run `git submodule update --init --recursive` from the ZiggyRuntimeHooks repo root.",
            .{path},
        );
    };
}

pub fn build(b: *std.Build) void {
    requireSubmodule(b, "deps/ziggy-memory-store/build.zig.zon");
    requireSubmodule(b, "deps/ziggy-run-orchestrator/build.zig.zon");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziggy_memory_store_dep = b.dependency("ziggy_memory_store", .{
        .target = target,
        .optimize = optimize,
    });
    const ziggy_memory_store_module = ziggy_memory_store_dep.module("ziggy-memory-store");
    const ziggy_run_orchestrator_dep = b.dependency("ziggy_run_orchestrator", .{
        .target = target,
        .optimize = optimize,
    });
    const ziggy_run_orchestrator_module = ziggy_run_orchestrator_dep.module("ziggy-run-orchestrator");

    const lib = b.addModule("ziggy-runtime-hooks", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.addImport("ziggy-memory-store", ziggy_memory_store_module);
    lib.addImport("ziggy-run-orchestrator", ziggy_run_orchestrator_module);

    const lib_tests = b.addTest(.{ .root_module = lib });
    lib_tests.linkLibC();
    lib_tests.linkSystemLibrary("sqlite3");
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);
}
