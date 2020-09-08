const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zig-walkdir", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var all_tests = b.addTest("src/all_test.zig");
    all_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&all_tests.step);

    var example = b.addExecutable("example", "examples/basic.zig");
    example.addPackagePath("walkdir", "src/main.zig");
    example.setBuildMode(mode);

    var example_run = example.run();

    const example_step = b.step("example", "Run example");
    example_step.dependOn(&example_run.step);
}
