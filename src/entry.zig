const std = @import("std");

pub const Entry = struct {
    name: []const u8,
    absolute_path: []u8,
    relative_path: []u8,
    kind: std.fs.Dir.Entry.Kind,
};
