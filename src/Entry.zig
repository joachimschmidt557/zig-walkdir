const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = @This();

allocator: Allocator,

/// The file or directory name of the entry
name: []const u8,

/// The absolute path of the entry
absolute_path: []const u8,

/// The path relative to the traversal start
relative_path: []const u8,
kind: std.fs.Dir.Entry.Kind,

pub fn deinit(entry: Entry) void {
    entry.allocator.free(entry.absolute_path);
}
