const Build = @import("std").Build;
const FileSource = Build.FileSource;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("walkdir", .{
        .source_file = .{ .path = "src/main.zig" },
    });

    var main_tests = b.addTest(.{
        .root_source_file = FileSource.relative("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    var example = b.addExecutable(.{
        .name = "example",
        .root_source_file = FileSource.relative("examples/basic.zig"),
        .target = target,
        .optimize = optimize,
    });
    example.addModule("walkdir", module);

    var example_run = example.run();

    const example_step = b.step("example", "Run example");
    example_step.dependOn(&example_run.step);
}
