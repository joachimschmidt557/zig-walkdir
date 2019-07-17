const std = @import("std");
const testing = std.testing;

const BreadthFirstWalker = @import("breadth_first.zig").BreadthFirstWalker;
const DepthFirstWalker = @import("depth_first.zig").DepthFirstWalker;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    testing.expect(add(3, 7) == 10);
}
