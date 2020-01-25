const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Entry = struct {
    allocator: *Allocator,
    name: []const u8,
    absolute_path: []u8,
    relative_path: []u8,
    kind: std.fs.Dir.Entry.Kind,

    const Self = @This();

    pub fn deinit(self: Self) void {
        self.alloc.free(absolute_path);
    }
};
