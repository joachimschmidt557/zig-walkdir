test "all" {
    _ = @import("main.zig");
    _ = @import("entry.zig");
    _ = @import("breadth_first.zig");
    _ = @import("depth_first.zig");
}
